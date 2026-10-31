import 'dart:convert';

import 'package:http/http.dart' as http;

/// An error the API sent back, e.g. code "seat_taken" with a readable message.
class ApiException implements Exception {
  ApiException(this.status, this.code, this.message);

  final int status;
  final String code;
  final String message;

  @override
  String toString() => message;
}

/// Thin wrapper over package:http. Every call:
///  * adds the JSON headers and the Bearer token when logged in,
///  * turns {"error": {...}} responses into an [ApiException],
///  * waits up to 60 s, because a sleeping free server takes ~50 s to wake.
class ApiClient {
  ApiClient(this.baseUrl);

  String baseUrl;
  String? token;

  /// Called when a request made with a token comes back 401 (token expired
  /// or account deleted), so the app can log out instead of showing errors.
  void Function()? onUnauthorized;
  final http.Client _http = http.Client();

  static const _timeout = Duration(seconds: 60);

  Uri _uri(String path, [Map<String, String>? query]) {
    final base = baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl;
    return Uri.parse('$base/api$path').replace(queryParameters: query);
  }

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      };

  Future<Map<String, dynamic>> get(String path, {Map<String, String>? query}) =>
      _send(() => _http.get(_uri(path, query), headers: _headers));

  Future<Map<String, dynamic>> post(String path, [Map<String, dynamic>? body]) =>
      _send(() => _http.post(_uri(path), headers: _headers, body: jsonEncode(body ?? {})));

  Future<Map<String, dynamic>> patch(String path, Map<String, dynamic> body) =>
      _send(() => _http.patch(_uri(path), headers: _headers, body: jsonEncode(body)));

  Future<Map<String, dynamic>> _send(Future<http.Response> Function() request) async {
    final http.Response res;
    try {
      res = await request().timeout(_timeout);
    } on Exception {
      throw ApiException(0, 'network', 'Cannot reach the server at $baseUrl. Check the connection or the server address.');
    }
    Map<String, dynamic> body;
    try {
      body = res.body.isEmpty ? {} : jsonDecode(res.body) as Map<String, dynamic>;
    } on FormatException {
      throw ApiException(res.statusCode, 'bad_response', 'The server sent something unexpected (HTTP ${res.statusCode}).');
    }
    if (res.statusCode == 401 && token != null) onUnauthorized?.call();
    if (res.statusCode >= 400) {
      final err = body['error'] as Map<String, dynamic>? ?? {};
      throw ApiException(
        res.statusCode,
        err['code'] as String? ?? 'error',
        err['message'] as String? ?? 'Request failed (HTTP ${res.statusCode})',
      );
    }
    return body;
  }
}

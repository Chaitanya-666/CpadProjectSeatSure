import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../api/api_client.dart';
import '../models/models.dart';

/// Where the API lives, unless the user changed it in Server settings.
///  * Release builds pass --dart-define=API_BASE_URL=https://... (see README).
///  * The web build is served by the API itself, so it uses its own origin.
///  * Otherwise: Android emulator -> 10.0.2.2 is the host machine's localhost.
String defaultServerUrl() {
  const fromBuild = String.fromEnvironment('API_BASE_URL');
  if (fromBuild.isNotEmpty) return fromBuild;
  if (kIsWeb) return Uri.base.origin;
  if (defaultTargetPlatform == TargetPlatform.android) return 'http://10.0.2.2:3000';
  return 'http://localhost:3000';
}

/// Who is logged in, which server we talk to, and that server's booking
/// rules. Saved in SharedPreferences so the app reopens logged in.
class Session extends ChangeNotifier {
  Session(this.prefs) : api = ApiClient(prefs.getString(_kServer) ?? defaultServerUrl()) {
    api.onUnauthorized = () {
      if (!restoring && loggedIn) logout();
    };
  }

  static const _kServer = 'server_url';
  static const _kToken = 'token';
  static const _kUser = 'user';

  final SharedPreferences prefs;
  final ApiClient api;

  User? user;
  BookingRules rules = BookingRules.fallback;
  bool restoring = true;

  bool get loggedIn => user != null;
  String get serverUrl => api.baseUrl;

  /// On start-up: reuse the saved token if the server still accepts it.
  Future<void> restore() async {
    final token = prefs.getString(_kToken);
    final savedUser = prefs.getString(_kUser);
    if (token != null && savedUser != null) {
      api.token = token;
      user = User.fromJson(jsonDecode(savedUser) as Map<String, dynamic>);
      try {
        final me = await api.get('/auth/me');
        user = User.fromJson(me['user'] as Map<String, dynamic>);
      } on ApiException catch (e) {
        if (e.status == 401) await _clear();
        // Offline: keep the saved user; screens show the network error.
      }
    }
    await loadRules();
    restoring = false;
    notifyListeners();
  }

  Future<void> loadRules() async {
    try {
      rules = BookingRules.fromJson(await api.get('/config'));
    } on ApiException {
      // keep the previous rules
    }
  }

  Future<void> login(String email, String password) async {
    final res = await api.post('/auth/login', {'email': email, 'password': password});
    await _save(res);
  }

  Future<void> register(String name, String email, String password) async {
    final res = await api.post('/auth/register', {'name': name, 'email': email, 'password': password});
    await _save(res);
  }

  Future<void> logout() async {
    await _clear();
    notifyListeners();
  }

  /// Test the new address with /health before switching to it.
  Future<void> setServerUrl(String url) async {
    final old = api.baseUrl;
    api.baseUrl = url.trim();
    try {
      await api.get('/health');
    } catch (_) {
      api.baseUrl = old;
      rethrow;
    }
    await prefs.setString(_kServer, api.baseUrl);
    await _clear(); // a token from another server means nothing here
    await loadRules();
    notifyListeners();
  }

  Future<void> _save(Map<String, dynamic> res) async {
    api.token = res['token'] as String;
    user = User.fromJson(res['user'] as Map<String, dynamic>);
    await prefs.setString(_kToken, api.token!);
    await prefs.setString(_kUser, jsonEncode(user!.toJson()));
    await loadRules();
    notifyListeners();
  }

  Future<void> _clear() async {
    api.token = null;
    user = null;
    await prefs.remove(_kToken);
    await prefs.remove(_kUser);
  }
}

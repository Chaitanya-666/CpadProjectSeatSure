import 'package:flutter/foundation.dart';

import '../api/api_client.dart';
import '../models/models.dart';

/// The logged-in student's bookings, shared by the My bookings and Scan tabs
/// so a check-in on one tab shows up on the other at once.
class BookingsModel extends ChangeNotifier {
  BookingsModel(this.api);

  final ApiClient api;

  List<Booking> upcoming = [];
  List<Booking> history = [];
  bool loading = false;
  String? error;

  Future<void> refresh() async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      final results = await Future.wait([
        api.get('/bookings/me', query: {'scope': 'upcoming'}),
        api.get('/bookings/me', query: {'scope': 'history'}),
      ]);
      upcoming = _parse(results[0]);
      history = _parse(results[1]);
    } on ApiException catch (e) {
      error = e.message;
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<Booking> book({required int seatId, required DateTime start, required DateTime end}) async {
    final res = await api.post('/bookings', {
      'seatId': seatId,
      'start': start.toUtc().toIso8601String(),
      'end': end.toUtc().toIso8601String(),
    });
    await refresh();
    return Booking.fromJson(res['booking'] as Map<String, dynamic>);
  }

  Future<void> cancel(Booking b) async {
    await api.post('/bookings/${b.id}/cancel');
    await refresh();
  }

  Future<void> checkout(Booking b) async {
    await api.post('/bookings/${b.id}/checkout');
    await refresh();
  }

  Future<Booking> checkin(String qrToken) async {
    final res = await api.post('/checkin', {'qrToken': qrToken});
    await refresh();
    return Booking.fromJson(res['booking'] as Map<String, dynamic>);
  }

  void clear() {
    upcoming = [];
    history = [];
    error = null;
    notifyListeners();
  }

  static List<Booking> _parse(Map<String, dynamic> res) =>
      (res['bookings'] as List).map((b) => Booking.fromJson(b as Map<String, dynamic>)).toList();
}

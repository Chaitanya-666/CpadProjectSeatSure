import 'package:flutter_test/flutter_test.dart';
import 'package:seatsure/models/models.dart';

Map<String, dynamic> bookingJson({required DateTime start, String status = 'booked'}) => {
      'id': 7,
      'status': status,
      'start': start.toUtc().toIso8601String(),
      'end': start.add(const Duration(hours: 1)).toUtc().toIso8601String(),
      'seat': {'id': 1, 'label': 'A1', 'hasPower': true},
      'room': {'id': 1, 'name': 'Central Reading Hall', 'floor': 'Ground floor'},
      'checkedInAt': null,
      'endedAt': null,
      'createdAt': start.toUtc().toIso8601String(),
      'checkinOpensAt': start.subtract(const Duration(minutes: 10)).toUtc().toIso8601String(),
      'checkinDeadline': start.add(const Duration(minutes: 15)).toUtc().toIso8601String(),
    };

void main() {
  group('Booking', () {
    final start = DateTime(2026, 11, 2, 10);

    test('parses API JSON and converts UTC to local time', () {
      final b = Booking.fromJson(bookingJson(start: start));
      expect(b.start, start);
      expect(b.seatLabel, 'A1');
      expect(b.roomName, 'Central Reading Hall');
      expect(b.userName, isNull);
    });

    test('check-in window is [start - 10 min, start + 15 min)', () {
      final b = Booking.fromJson(bookingJson(start: start));
      expect(b.canCheckIn(start.subtract(const Duration(minutes: 11))), isFalse);
      expect(b.canCheckIn(start.subtract(const Duration(minutes: 10))), isTrue);
      expect(b.canCheckIn(start.add(const Duration(minutes: 14))), isTrue);
      expect(b.canCheckIn(start.add(const Duration(minutes: 15))), isFalse);
    });

    test('only booked can be cancelled; only checked-in before the end can check out', () {
      final booked = Booking.fromJson(bookingJson(start: start));
      final inSeat = Booking.fromJson(bookingJson(start: start, status: 'checked_in'));
      expect(booked.canCancel, isTrue);
      expect(inSeat.canCancel, isFalse);
      expect(inSeat.canCheckOut(start.add(const Duration(minutes: 30))), isTrue);
      expect(inSeat.canCheckOut(start.add(const Duration(hours: 1))), isFalse);
    });
  });

  test('Room converts HH:MM opening hours to minutes', () {
    final r = Room.fromJson({'id': 1, 'name': 'R', 'openTime': '08:30', 'closeTime': '22:00'});
    expect(r.openMinutes, 510);
    expect(r.closeMinutes, 1320);
  });
}

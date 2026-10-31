// Plain data classes built from the API's JSON. Times arrive as UTC ISO
// strings and are converted to the phone's local time with toLocal().

DateTime _time(Object? v) => DateTime.parse(v as String).toLocal();
DateTime? _timeOrNull(Object? v) => v == null ? null : _time(v);

class User {
  User({required this.id, required this.name, required this.email, required this.role});

  factory User.fromJson(Map<String, dynamic> j) =>
      User(id: j['id'] as int, name: j['name'] as String, email: j['email'] as String, role: j['role'] as String);

  final int id;
  final String name;
  final String email;
  final String role;

  bool get isAdmin => role == 'admin';

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'email': email, 'role': role};
}

/// Booking rules served by GET /api/config, so the pickers match the server.
class BookingRules {
  BookingRules({
    required this.stepMinutes,
    required this.minMinutes,
    required this.maxMinutes,
    required this.horizonDays,
    required this.maxActivePerUser,
    required this.checkinEarlyMinutes,
    required this.checkinGraceMinutes,
  });

  factory BookingRules.fromJson(Map<String, dynamic> j) => BookingRules(
        stepMinutes: j['stepMinutes'] as int,
        minMinutes: j['minMinutes'] as int,
        maxMinutes: j['maxMinutes'] as int,
        horizonDays: j['horizonDays'] as int,
        maxActivePerUser: j['maxActivePerUser'] as int,
        checkinEarlyMinutes: j['checkinEarlyMinutes'] as int,
        checkinGraceMinutes: j['checkinGraceMinutes'] as int,
      );

  static final fallback = BookingRules(
    stepMinutes: 15,
    minMinutes: 30,
    maxMinutes: 240,
    horizonDays: 7,
    maxActivePerUser: 3,
    checkinEarlyMinutes: 10,
    checkinGraceMinutes: 15,
  );

  final int stepMinutes;
  final int minMinutes;
  final int maxMinutes;
  final int horizonDays;
  final int maxActivePerUser;
  final int checkinEarlyMinutes;
  final int checkinGraceMinutes;
}

class Room {
  Room({
    required this.id,
    required this.name,
    required this.description,
    required this.floor,
    required this.openTime,
    required this.closeTime,
    this.seatCount = 0,
    this.freeNow = 0,
    this.isActive = true,
  });

  factory Room.fromJson(Map<String, dynamic> j) => Room(
        id: j['id'] as int,
        name: j['name'] as String,
        description: j['description'] as String? ?? '',
        floor: j['floor'] as String? ?? '',
        openTime: j['openTime'] as String,
        closeTime: j['closeTime'] as String,
        seatCount: j['seatCount'] as int? ?? 0,
        freeNow: j['freeNow'] as int? ?? 0,
        isActive: j['isActive'] as bool? ?? true,
      );

  final int id;
  final String name;
  final String description;
  final String floor;
  final String openTime; // "HH:MM" local
  final String closeTime;
  final int seatCount;
  final int freeNow;
  final bool isActive;

  int get openMinutes => _minutes(openTime);
  int get closeMinutes => _minutes(closeTime);
  static int _minutes(String hhmm) => int.parse(hhmm.substring(0, 2)) * 60 + int.parse(hhmm.substring(3, 5));
}

enum SeatState { free, taken, mine }

class SeatAvailability {
  SeatAvailability({required this.id, required this.label, required this.hasPower, required this.state});

  factory SeatAvailability.fromJson(Map<String, dynamic> j) => SeatAvailability(
        id: j['id'] as int,
        label: j['label'] as String,
        hasPower: j['hasPower'] as bool,
        state: SeatState.values.byName(j['state'] as String),
      );

  final int id;
  final String label;
  final bool hasPower;
  final SeatState state;
}

/// A seat as the admin sees it, including the secret QR token.
class AdminSeat {
  AdminSeat({required this.id, required this.label, required this.hasPower, required this.qrToken, required this.isActive});

  factory AdminSeat.fromJson(Map<String, dynamic> j) => AdminSeat(
        id: j['id'] as int,
        label: j['label'] as String,
        hasPower: j['hasPower'] as bool,
        qrToken: j['qrToken'] as String,
        isActive: j['isActive'] as bool,
      );

  final int id;
  final String label;
  final bool hasPower;
  final String qrToken;
  final bool isActive;
}

class Booking {
  Booking({
    required this.id,
    required this.status,
    required this.start,
    required this.end,
    required this.seatLabel,
    required this.seatHasPower,
    required this.roomName,
    required this.roomFloor,
    required this.checkinOpensAt,
    required this.checkinDeadline,
    this.checkedInAt,
    this.endedAt,
    this.userName,
    this.userEmail,
  });

  factory Booking.fromJson(Map<String, dynamic> j) {
    final seat = j['seat'] as Map<String, dynamic>;
    final room = j['room'] as Map<String, dynamic>;
    final user = j['user'] as Map<String, dynamic>?;
    return Booking(
      id: j['id'] as int,
      status: j['status'] as String,
      start: _time(j['start']),
      end: _time(j['end']),
      seatLabel: seat['label'] as String,
      seatHasPower: seat['hasPower'] as bool? ?? false,
      roomName: room['name'] as String,
      roomFloor: room['floor'] as String? ?? '',
      checkinOpensAt: _time(j['checkinOpensAt']),
      checkinDeadline: _time(j['checkinDeadline']),
      checkedInAt: _timeOrNull(j['checkedInAt']),
      endedAt: _timeOrNull(j['endedAt']),
      userName: user?['name'] as String?,
      userEmail: user?['email'] as String?,
    );
  }

  final int id;
  final String status; // booked | checked_in | completed | cancelled | no_show
  final DateTime start;
  final DateTime end;
  final String seatLabel;
  final bool seatHasPower;
  final String roomName;
  final String roomFloor;
  final DateTime checkinOpensAt;
  final DateTime checkinDeadline;
  final DateTime? checkedInAt;
  final DateTime? endedAt;
  final String? userName;
  final String? userEmail;

  bool get canCancel => status == 'booked';
  bool canCheckIn(DateTime now) => status == 'booked' && !now.isBefore(checkinOpensAt) && now.isBefore(checkinDeadline);
  bool canCheckOut(DateTime now) => status == 'checked_in' && now.isBefore(end);
}

class RoomStats {
  RoomStats.fromJson(Map<String, dynamic> j)
      : name = j['name'] as String,
        bookings = j['bookings'] as int,
        attended = j['attended'] as int,
        noShows = j['noShows'] as int,
        cancelled = j['cancelled'] as int,
        noShowRate = (j['noShowRate'] as num).toDouble(),
        hoursUsed = (j['hoursUsed'] as num).toDouble();

  final String name;
  final int bookings;
  final int attended;
  final int noShows;
  final int cancelled;
  final double noShowRate;
  final double hoursUsed;
}

class AdminStats {
  AdminStats.fromJson(Map<String, dynamic> j)
      : days = j['days'] as int,
        inUse = (j['now'] as Map)['inUse'] as int,
        held = (j['now'] as Map)['held'] as int,
        seats = (j['now'] as Map)['seats'] as int,
        students = j['students'] as int,
        rooms = (j['rooms'] as List).map((r) => RoomStats.fromJson(r as Map<String, dynamic>)).toList(),
        byHour = {
          for (final h in j['byHour'] as List) (h as Map)['hour'] as int: h['bookings'] as int,
        };

  final int days;
  final int inUse;
  final int held;
  final int seats;
  final int students;
  final List<RoomStats> rooms;
  final Map<int, int> byHour;
}

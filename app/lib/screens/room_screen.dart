import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api/api_client.dart';
import '../models/models.dart';
import '../state/bookings_model.dart';
import '../state/session.dart';
import '../widgets/common.dart';

/// Pick a day, start time and length, then tap a free seat to book it.
/// The seat map refreshes every 15 seconds, so a seat booked on another
/// phone turns grey here without touching anything.
class RoomScreen extends StatefulWidget {
  const RoomScreen({super.key, required this.room});

  final Room room;

  @override
  State<RoomScreen> createState() => _RoomScreenState();
}

class _RoomScreenState extends State<RoomScreen> {
  late BookingRules _rules;
  late DateTime _day; // local midnight
  int? _startMinute; // minutes after midnight
  int _length = 60;

  List<SeatAvailability>? _seats;
  String? _error;
  bool _booking = false;
  Timer? _poll;

  @override
  void initState() {
    super.initState();
    _rules = context.read<Session>().rules;
    final now = DateTime.now();
    _day = DateTime(now.year, now.month, now.day);
    _pickFirstStart();
    _load();
    _poll = Timer.periodic(const Duration(seconds: 15), (_) => _load(quiet: true));
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  /// Start times the server will accept: on the step grid, inside opening
  /// hours with room for the shortest booking, and not already past.
  List<int> get _startOptions {
    final room = widget.room;
    final now = DateTime.now();
    final isToday = DateUtils.isSameDay(_day, now);
    final nowMinute = now.hour * 60 + now.minute;
    final currentBlock = nowMinute - nowMinute % _rules.stepMinutes;
    return [
      for (var m = room.openMinutes; m + _rules.minMinutes <= room.closeMinutes; m += _rules.stepMinutes)
        if (!isToday || m >= currentBlock) m,
    ];
  }

  List<int> get _lengthOptions {
    final start = _startMinute;
    if (start == null) return [];
    return [
      for (var l = _rules.minMinutes; l <= _rules.maxMinutes; l += 30)
        if (start + l <= widget.room.closeMinutes) l,
    ];
  }

  void _pickFirstStart() {
    final options = _startOptions;
    _startMinute = options.isEmpty ? null : options.first;
    final lengths = _lengthOptions;
    if (lengths.isNotEmpty && !lengths.contains(_length)) _length = lengths.last < 60 ? lengths.last : 60;
  }

  DateTime get _start => _day.add(Duration(minutes: _startMinute!));
  DateTime get _end => _start.add(Duration(minutes: _length));

  Future<void> _load({bool quiet = false}) async {
    if (_startMinute == null) {
      setState(() => _seats = []);
      return;
    }
    if (!quiet) setState(() => _error = null);
    try {
      final res = await context.read<Session>().api.get('/rooms/${widget.room.id}/availability', query: {
        'start': _start.toUtc().toIso8601String(),
        'end': _end.toUtc().toIso8601String(),
      });
      if (!mounted) return;
      setState(() {
        _seats = (res['seats'] as List).map((s) => SeatAvailability.fromJson(s as Map<String, dynamic>)).toList();
        _error = null;
      });
    } on ApiException catch (e) {
      if (mounted && !quiet) setState(() => _error = e.message);
    }
  }

  void _changed(VoidCallback change) {
    setState(() {
      change();
      final lengths = _lengthOptions;
      if (lengths.isNotEmpty && !lengths.contains(_length)) _length = lengths.last;
      _seats = null;
    });
    _load();
  }

  Future<void> _book(SeatAvailability seat) async {
    final theme = Theme.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Book seat ${seat.label}?'),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(widget.room.name, style: theme.textTheme.titleSmall),
          Text(slotText(_start, _end)),
          if (seat.hasPower) const Text('Has a power socket'),
          const SizedBox(height: 12),
          Text(
            'Scan the QR code on the seat within ${_rules.checkinGraceMinutes} minutes of the start, '
            'or the seat is released for others.',
            style: theme.textTheme.bodySmall,
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Book')),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    setState(() => _booking = true);
    try {
      final booking = await context.read<BookingsModel>().book(seatId: seat.id, start: _start, end: _end);
      if (!mounted) return;
      showInfo(context, 'Booked ${booking.seatLabel}. Check in from ${timeFmt.format(booking.checkinOpensAt)}.');
      Navigator.pop(context, true);
    } on ApiException catch (e) {
      if (!mounted) return;
      showError(context, e);
      _load(); // someone else may have taken it: show the fresh map
    } finally {
      if (mounted) setState(() => _booking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final starts = _startOptions;
    final days = List.generate(_rules.horizonDays + 1, (i) => _today.add(Duration(days: i)));
    return Scaffold(
      appBar: AppBar(title: Text(widget.room.name)),
      body: Column(children: [
        // ---- day chips ----
        SizedBox(
          height: 56,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            children: [
              for (final d in days)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(DateUtils.isSameDay(d, _today) ? 'Today' : dayFmt.format(d)),
                    selected: DateUtils.isSameDay(d, _day),
                    onSelected: (_) => _changed(() {
                      _day = d;
                      _pickFirstStart();
                    }),
                  ),
                ),
            ],
          ),
        ),
        // ---- time pickers ----
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: starts.isEmpty
              ? const Text('This room is closed for the rest of the day. Pick another day.')
              : Row(children: [
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      initialValue: _startMinute,
                      decoration: const InputDecoration(labelText: 'From', border: OutlineInputBorder()),
                      items: [
                        for (final m in starts)
                          DropdownMenuItem(value: m, child: Text(timeFmt.format(_day.add(Duration(minutes: m))))),
                      ],
                      onChanged: (v) => _changed(() => _startMinute = v),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      key: ValueKey('len-$_startMinute'),
                      initialValue: _length,
                      decoration: const InputDecoration(labelText: 'For', border: OutlineInputBorder()),
                      items: [
                        for (final l in _lengthOptions)
                          DropdownMenuItem(value: l, child: Text(l < 60 ? '$l min' : '${l / 60} h'.replaceAll('.0', ''))),
                      ],
                      onChanged: (v) => _changed(() => _length = v!),
                    ),
                  ),
                ]),
        ),
        const _Legend(),
        const Divider(height: 1),
        // ---- seat grid ----
        Expanded(
          child: switch ((_seats, _error)) {
            (_, final String err) => ErrorRetry(message: err, onRetry: _load),
            (null, _) => const Center(child: CircularProgressIndicator()),
            (final List<SeatAvailability> seats, _) when seats.isEmpty =>
              const EmptyState(icon: Icons.event_busy, text: 'No seats to show for this time.'),
            (final List<SeatAvailability> seats, _) => RefreshIndicator(
                onRefresh: _load,
                child: GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 88,
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                  ),
                  itemCount: seats.length,
                  itemBuilder: (context, i) => _SeatTile(
                    seat: seats[i],
                    onTap: seats[i].state == SeatState.free && !_booking ? () => _book(seats[i]) : null,
                  ),
                ),
              ),
          },
        ),
      ]),
    );
  }

  DateTime get _today {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }
}

class _SeatTile extends StatelessWidget {
  const _SeatTile({required this.seat, this.onTap});

  final SeatAvailability seat;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (bg, fg) = switch (seat.state) {
      SeatState.free => (Colors.green.shade600, Colors.white),
      SeatState.mine => (scheme.primary, scheme.onPrimary),
      SeatState.taken => (scheme.surfaceContainerHighest, scheme.onSurfaceVariant),
    };
    return Semantics(
      button: onTap != null,
      label: 'Seat ${seat.label}, ${seat.state.name}',
      child: Material(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(seat.state == SeatState.taken ? Icons.event_seat_outlined : Icons.event_seat, color: fg),
            Text(seat.label, style: TextStyle(color: fg, fontWeight: FontWeight.w700)),
            if (seat.hasPower) Icon(Icons.power, size: 14, color: fg),
          ]),
        ),
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    Widget dot(Color c, String t) => Row(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 12, height: 12, decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(3))),
          const SizedBox(width: 4),
          Text(t, style: Theme.of(context).textTheme.bodySmall),
        ]);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Wrap(spacing: 16, runSpacing: 4, children: [
        dot(Colors.green.shade600, 'Free'),
        dot(scheme.primary, 'Yours'),
        dot(scheme.surfaceContainerHighest, 'Taken'),
        const Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.power, size: 14), Text(' Power socket')]),
      ]),
    );
  }
}

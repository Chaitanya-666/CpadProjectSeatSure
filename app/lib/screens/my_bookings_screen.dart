import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../state/bookings_model.dart';
import '../widgets/common.dart';

/// Upcoming and past bookings. Upcoming cards show the check-in window and
/// a live countdown, which is the in-app reminder to go and scan the seat.
class MyBookingsScreen extends StatefulWidget {
  const MyBookingsScreen({super.key});

  @override
  State<MyBookingsScreen> createState() => _MyBookingsScreenState();
}

class _MyBookingsScreenState extends State<MyBookingsScreen> {
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    // Re-render every 30 s so countdowns and button states stay current.
    _tick = Timer.periodic(const Duration(seconds: 30), (_) => setState(() {}));
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final model = context.watch<BookingsModel>();
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('My bookings'),
          actions: [IconButton(tooltip: 'Refresh', onPressed: model.refresh, icon: const Icon(Icons.refresh))],
          bottom: TabBar(tabs: [
            Tab(text: 'Upcoming (${model.upcoming.length})'),
            const Tab(text: 'History'),
          ]),
        ),
        body: model.error != null && model.upcoming.isEmpty && model.history.isEmpty
            ? ErrorRetry(message: model.error!, onRetry: model.refresh)
            : TabBarView(children: [
                _List(
                  bookings: model.upcoming,
                  empty: 'No upcoming bookings. Pick a room to book a seat.',
                  loading: model.loading,
                ),
                _List(bookings: model.history, empty: 'Nothing here yet.', loading: model.loading),
              ]),
      ),
    );
  }
}

class _List extends StatelessWidget {
  const _List({required this.bookings, required this.empty, required this.loading});

  final List<Booking> bookings;
  final String empty;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final model = context.read<BookingsModel>();
    if (bookings.isEmpty) {
      return loading ? const Center(child: CircularProgressIndicator()) : EmptyState(icon: Icons.bookmark_border, text: empty);
    }
    return RefreshIndicator(
      onRefresh: model.refresh,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: bookings.length,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (context, i) => BookingCard(booking: bookings[i]),
      ),
    );
  }
}

class BookingCard extends StatelessWidget {
  const BookingCard({super.key, required this.booking});

  final Booking booking;

  String _until(DateTime t) {
    final d = t.difference(DateTime.now());
    if (d.inMinutes < 1) return 'less than a minute';
    if (d.inHours < 1) return '${d.inMinutes} min';
    if (d.inHours < 24) return '${d.inHours} h ${d.inMinutes % 60} min';
    return '${d.inDays} days';
  }

  Future<void> _run(BuildContext context, Future<void> Function() action, String done) async {
    try {
      await action();
      if (context.mounted) showInfo(context, done);
    } catch (e) {
      if (context.mounted) showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final model = context.read<BookingsModel>();
    final b = booking;
    final now = DateTime.now();

    String? hint;
    Color? hintColor;
    if (b.status == 'booked') {
      if (now.isBefore(b.checkinOpensAt)) {
        hint = 'Check-in opens in ${_until(b.checkinOpensAt)} (${timeFmt.format(b.checkinOpensAt)})';
      } else if (now.isBefore(b.checkinDeadline)) {
        hint = 'Check in now! Scan the seat QR within ${_until(b.checkinDeadline)}, or the seat is released.';
        hintColor = theme.colorScheme.error;
      }
    } else if (b.status == 'checked_in' && now.isBefore(b.end)) {
      hint = 'Seat is yours until ${timeFmt.format(b.end)}';
      hintColor = Colors.green.shade700;
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text('Seat ${b.seatLabel} · ${b.roomName}', style: theme.textTheme.titleMedium)),
            StatusChip(b.status),
          ]),
          const SizedBox(height: 4),
          Text(slotText(b.start, b.end)),
          if (b.roomFloor.isNotEmpty)
            Text(b.roomFloor, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          if (b.checkedInAt != null)
            Text('Checked in at ${timeFmt.format(b.checkedInAt!)}', style: theme.textTheme.bodySmall),
          if (b.endedAt != null) Text('Left at ${timeFmt.format(b.endedAt!)}', style: theme.textTheme.bodySmall),
          if (hint != null) ...[
            const SizedBox(height: 8),
            Text(hint, style: theme.textTheme.bodyMedium?.copyWith(color: hintColor, fontWeight: FontWeight.w600)),
          ],
          if (b.canCancel || b.canCheckOut(now))
            Align(
              alignment: Alignment.centerRight,
              child: Wrap(spacing: 8, children: [
                if (b.canCancel)
                  TextButton(
                    onPressed: () => _run(context, () => model.cancel(b), 'Booking cancelled, seat released'),
                    child: const Text('Cancel booking'),
                  ),
                if (b.canCheckOut(now))
                  FilledButton.tonal(
                    onPressed: () => _run(context, () => model.checkout(b), 'Checked out. Thanks for freeing the seat!'),
                    child: const Text('Leave early'),
                  ),
              ]),
            ),
        ]),
      ),
    );
  }
}

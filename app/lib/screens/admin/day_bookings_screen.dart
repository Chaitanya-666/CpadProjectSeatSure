import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../api/api_client.dart';
import '../../models/models.dart';
import '../../state/session.dart';
import '../../widgets/common.dart';

/// Every booking on one day, with the student's name (admins only).
class DayBookingsScreen extends StatefulWidget {
  const DayBookingsScreen({super.key});

  @override
  State<DayBookingsScreen> createState() => _DayBookingsScreenState();
}

class _DayBookingsScreenState extends State<DayBookingsScreen> {
  DateTime _day = DateUtils.dateOnly(DateTime.now());
  List<Booking>? _bookings;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _error = null;
      _bookings = null;
    });
    try {
      final res = await context
          .read<Session>()
          .api
          .get('/admin/bookings', query: {'date': DateFormat('yyyy-MM-dd').format(_day)});
      setState(() => _bookings = (res['bookings'] as List).map((b) => Booking.fromJson(b as Map<String, dynamic>)).toList());
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    }
  }

  Future<void> _pickDay() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _day,
      firstDate: DateTime.now().subtract(const Duration(days: 90)),
      lastDate: DateTime.now().add(const Duration(days: 30)),
    );
    if (picked != null) {
      _day = picked;
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Bookings · ${dayFmt.format(_day)}'),
        actions: [
          IconButton(tooltip: 'Pick day', onPressed: _pickDay, icon: const Icon(Icons.calendar_month)),
          IconButton(tooltip: 'Refresh', onPressed: _load, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: switch ((_bookings, _error)) {
        (_, final String err) => ErrorRetry(message: err, onRetry: _load),
        (null, _) => const Center(child: CircularProgressIndicator()),
        (final List<Booking> list, _) when list.isEmpty =>
          const EmptyState(icon: Icons.event_busy, text: 'No bookings on this day.'),
        (final List<Booking> list, _) => RefreshIndicator(
            onRefresh: _load,
            child: ListView.separated(
              itemCount: list.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, i) {
                final b = list[i];
                return ListTile(
                  leading: CircleAvatar(child: Text(b.seatLabel, style: const TextStyle(fontSize: 12))),
                  title: Text('${b.userName} · ${b.roomName}'),
                  subtitle: Text('${timeFmt.format(b.start)} – ${timeFmt.format(b.end)} · ${b.userEmail}'),
                  trailing: StatusChip(b.status),
                );
              },
            ),
          ),
      },
    );
  }
}

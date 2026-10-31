import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../api/api_client.dart';
import '../../models/models.dart';
import '../../state/session.dart';
import '../../widgets/common.dart';

/// Seats of one room with their QR codes. On the web build this page is the
/// printable QR sheet: print it and stick each code on its desk.
class RoomSeatsScreen extends StatefulWidget {
  const RoomSeatsScreen({super.key, required this.room});

  final Room room;

  @override
  State<RoomSeatsScreen> createState() => _RoomSeatsScreenState();
}

class _RoomSeatsScreenState extends State<RoomSeatsScreen> {
  List<AdminSeat>? _seats;
  String? _error;

  ApiClient get _api => context.read<Session>().api;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final res = await _api.get('/admin/rooms/${widget.room.id}/seats');
      setState(() => _seats = (res['seats'] as List).map((s) => AdminSeat.fromJson(s as Map<String, dynamic>)).toList());
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    }
  }

  Future<void> _addSeats() async {
    final prefix = TextEditingController();
    final count = TextEditingController(text: '4');
    var power = false;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          title: const Text('Add seats'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: prefix, decoration: const InputDecoration(labelText: 'Label prefix, e.g. E')),
            TextField(
              controller: count,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'How many'),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Power sockets'),
              value: power,
              onChanged: (v) => setLocal(() => power = v),
            ),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Add')),
          ],
        ),
      ),
    );
    if (ok != true) return;
    try {
      // Continue numbering after the existing seats with the same prefix.
      final p = prefix.text.trim();
      final used = (_seats ?? [])
          .where((s) => s.label.startsWith(p))
          .map((s) => int.tryParse(s.label.substring(p.length)) ?? 0)
          .fold<int>(0, (a, b) => a > b ? a : b);
      await _api.post('/admin/rooms/${widget.room.id}/seats', {
        'prefix': p,
        'from': used + 1,
        'count': int.tryParse(count.text) ?? 1,
        'hasPower': power,
      });
      _load();
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  Future<void> _seatMenu(AdminSeat seat, String action) async {
    try {
      if (action == 'rotate') {
        await _api.post('/admin/seats/${seat.id}/rotate-qr');
        if (mounted) showInfo(context, 'New QR for ${seat.label}. Reprint it; the old code no longer works.');
      } else {
        await _api.patch('/admin/seats/${seat.id}', {'isActive': !seat.isActive});
      }
      _load();
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.room.name),
        actions: [IconButton(tooltip: 'Add seats', onPressed: _addSeats, icon: const Icon(Icons.add))],
      ),
      body: switch ((_seats, _error)) {
        (_, final String err) => ErrorRetry(message: err, onRetry: _load),
        (null, _) => const Center(child: CircularProgressIndicator()),
        (final List<AdminSeat> seats, _) when seats.isEmpty =>
          const EmptyState(icon: Icons.event_seat_outlined, text: 'No seats yet. Tap + to add some.'),
        (final List<AdminSeat> seats, _) => GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 220,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 0.72,
            ),
            itemCount: seats.length,
            itemBuilder: (context, i) => _QrCard(seat: seats[i], onAction: (a) => _seatMenu(seats[i], a)),
          ),
      },
    );
  }
}

class _QrCard extends StatelessWidget {
  const _QrCard({required this.seat, required this.onAction});

  final AdminSeat seat;
  final void Function(String action) onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Opacity(
      opacity: seat.isActive ? 1 : 0.45,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(children: [
            Row(children: [
              Expanded(child: Text('Seat ${seat.label}', style: theme.textTheme.titleMedium)),
              if (seat.hasPower) const Icon(Icons.power, size: 18),
              PopupMenuButton<String>(
                onSelected: onAction,
                itemBuilder: (_) => [
                  const PopupMenuItem(value: 'rotate', child: Text('New QR code')),
                  PopupMenuItem(value: 'toggle', child: Text(seat.isActive ? 'Disable seat' : 'Enable seat')),
                ],
              ),
            ]),
            Expanded(
              // White box so the code scans in dark mode too.
              child: Container(
                color: Colors.white,
                padding: const EdgeInsets.all(6),
                child: QrImageView(data: seat.qrToken, backgroundColor: Colors.white),
              ),
            ),
            const SizedBox(height: 6),
            SelectableText(seat.qrToken, style: theme.textTheme.labelSmall, textAlign: TextAlign.center),
          ]),
        ),
      ),
    );
  }
}

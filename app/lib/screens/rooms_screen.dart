import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api/api_client.dart';
import '../models/models.dart';
import '../state/session.dart';
import '../widgets/common.dart';
import 'room_screen.dart';

/// List of library rooms with live "free now" counts.
class RoomsScreen extends StatefulWidget {
  const RoomsScreen({super.key, required this.onBooked});

  final VoidCallback onBooked;

  @override
  State<RoomsScreen> createState() => _RoomsScreenState();
}

class _RoomsScreenState extends State<RoomsScreen> {
  List<Room>? _rooms;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final res = await context.read<Session>().api.get('/rooms');
      setState(() => _rooms = (res['rooms'] as List).map((r) => Room.fromJson(r as Map<String, dynamic>)).toList());
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = context.select<Session, String>((s) => s.user?.name.split(' ').first ?? '');
    return Scaffold(
      appBar: AppBar(title: Text('Hi $name, pick a room')),
      body: switch ((_rooms, _error)) {
        (_, final String err) => ErrorRetry(message: err, onRetry: _load),
        (null, _) => const Center(child: CircularProgressIndicator()),
        (final List<Room> rooms, _) when rooms.isEmpty =>
          const EmptyState(icon: Icons.meeting_room_outlined, text: 'No rooms are open for booking yet.'),
        (final List<Room> rooms, _) => RefreshIndicator(
            onRefresh: _load,
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: rooms.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, i) => _RoomCard(
                room: rooms[i],
                onTap: () async {
                  final booked = await Navigator.push<bool>(
                    context,
                    MaterialPageRoute(builder: (_) => RoomScreen(room: rooms[i])),
                  );
                  _load();
                  if (booked == true) widget.onBooked();
                },
              ),
            ),
          ),
      },
    );
  }
}

class _RoomCard extends StatelessWidget {
  const _RoomCard({required this.room, required this.onTap});

  final Room room;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ratio = room.seatCount == 0 ? 0.0 : room.freeNow / room.seatCount;
    final color = ratio > 0.4 ? Colors.green : (ratio > 0.1 ? Colors.orange : theme.colorScheme.error);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: color.withValues(alpha: 0.15),
              child: Text('${room.freeNow}', style: theme.textTheme.titleLarge?.copyWith(color: color)),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(room.name, style: theme.textTheme.titleMedium),
                Text('${room.freeNow} of ${room.seatCount} seats free now · ${room.floor}'),
                Text(
                  'Open ${room.openTime}–${room.closeTime}',
                  style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
              ]),
            ),
            const Icon(Icons.chevron_right),
          ]),
        ),
      ),
    );
  }
}

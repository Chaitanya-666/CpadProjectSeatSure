import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../api/api_client.dart';
import '../../models/models.dart';
import '../../state/session.dart';
import '../../widgets/common.dart';
import 'room_seats_screen.dart';

/// Rooms as the admin sees them, including closed ones. Add a room, open or
/// close it for booking, and open its seats and QR codes.
class AdminRoomsScreen extends StatefulWidget {
  const AdminRoomsScreen({super.key});

  @override
  State<AdminRoomsScreen> createState() => _AdminRoomsScreenState();
}

class _AdminRoomsScreenState extends State<AdminRoomsScreen> {
  List<Room>? _rooms;
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
      final res = await _api.get('/admin/rooms');
      setState(() => _rooms = (res['rooms'] as List).map((r) => Room.fromJson(r as Map<String, dynamic>)).toList());
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    }
  }

  Future<void> _toggle(Room room, bool active) async {
    try {
      await _api.patch('/admin/rooms/${room.id}', {'isActive': active});
      _load();
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  Future<void> _addRoom() async {
    final created = await showDialog<bool>(context: context, builder: (_) => _NewRoomDialog(api: _api));
    if (created == true) _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Rooms and seats')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addRoom,
        icon: const Icon(Icons.add),
        label: const Text('Room'),
      ),
      body: switch ((_rooms, _error)) {
        (_, final String err) => ErrorRetry(message: err, onRetry: _load),
        (null, _) => const Center(child: CircularProgressIndicator()),
        (final List<Room> rooms, _) => RefreshIndicator(
            onRefresh: _load,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
              children: [
                for (final room in rooms)
                  Card(
                    child: ListTile(
                      title: Text(room.name),
                      subtitle: Text('${room.seatCount} seats · ${room.openTime}–${room.closeTime} · ${room.floor}'),
                      trailing: Switch(value: room.isActive, onChanged: (v) => _toggle(room, v)),
                      onTap: () async {
                        await Navigator.push(context, MaterialPageRoute(builder: (_) => RoomSeatsScreen(room: room)));
                        _load();
                      },
                    ),
                  ),
              ],
            ),
          ),
      },
    );
  }
}

class _NewRoomDialog extends StatefulWidget {
  const _NewRoomDialog({required this.api});

  final ApiClient api;

  @override
  State<_NewRoomDialog> createState() => _NewRoomDialogState();
}

class _NewRoomDialogState extends State<_NewRoomDialog> {
  final _name = TextEditingController();
  final _floor = TextEditingController();
  TimeOfDay _open = const TimeOfDay(hour: 8, minute: 0);
  TimeOfDay _close = const TimeOfDay(hour: 22, minute: 0);
  bool _busy = false;

  String _hhmm(TimeOfDay t) => '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  @override
  void dispose() {
    _name.dispose();
    _floor.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _busy = true);
    try {
      await widget.api.post('/admin/rooms', {
        'name': _name.text,
        'floor': _floor.text,
        'openTime': _hhmm(_open),
        'closeTime': _hhmm(_close),
      });
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    Future<void> pick(bool open) async {
      final t = await showTimePicker(context: context, initialTime: open ? _open : _close);
      if (t != null) setState(() => open ? _open = t : _close = t);
    }

    return AlertDialog(
      title: const Text('New room'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: _name, decoration: const InputDecoration(labelText: 'Name')),
        TextField(controller: _floor, decoration: const InputDecoration(labelText: 'Floor')),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: OutlinedButton(onPressed: () => pick(true), child: Text('Opens ${_hhmm(_open)}'))),
          const SizedBox(width: 8),
          Expanded(child: OutlinedButton(onPressed: () => pick(false), child: Text('Closes ${_hhmm(_close)}'))),
        ]),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(onPressed: _busy ? null : _save, child: const Text('Create')),
      ],
    );
  }
}

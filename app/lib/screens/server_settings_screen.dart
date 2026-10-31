import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/session.dart';
import '../widgets/common.dart';

/// Change which server the app talks to: the cloud API, or a laptop on the
/// same Wi-Fi/hotspot as a fallback (e.g. http://192.168.43.10:3000).
class ServerSettingsScreen extends StatefulWidget {
  const ServerSettingsScreen({super.key});

  @override
  State<ServerSettingsScreen> createState() => _ServerSettingsScreenState();
}

class _ServerSettingsScreenState extends State<ServerSettingsScreen> {
  late final _url = TextEditingController(text: context.read<Session>().serverUrl);
  bool _busy = false;

  @override
  void dispose() {
    _url.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _busy = true);
    try {
      await context.read<Session>().setServerUrl(_url.text);
      if (mounted) {
        showInfo(context, 'Connected. Please log in on this server.');
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Server')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text('The app checks /api/health on the new address before switching.'),
          const SizedBox(height: 16),
          TextField(
            controller: _url,
            keyboardType: TextInputType.url,
            decoration: const InputDecoration(labelText: 'Server address', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 12),
          Wrap(spacing: 8, children: [
            ActionChip(label: const Text('Default'), onPressed: () => _url.text = defaultServerUrl()),
            ActionChip(label: const Text('Emulator → laptop'), onPressed: () => _url.text = 'http://10.0.2.2:3000'),
          ]),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _busy ? null : _save,
            child: Text(_busy ? 'Checking… (a sleeping server can take ~50 s)' : 'Test and save'),
          ),
        ],
      ),
    );
  }
}

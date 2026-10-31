import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/session.dart';
import 'server_settings_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final session = context.watch<Session>();
    final user = session.user;
    if (user == null) return const SizedBox.shrink(); // logging out
    final rules = session.rules;
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ListTile(
            leading: CircleAvatar(child: Text(user.name.characters.first.toUpperCase())),
            title: Text(user.name),
            subtitle: Text(user.email),
            trailing: Chip(label: Text(user.isAdmin ? 'Admin' : 'Student')),
          ),
          const Divider(),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text('Booking rules', style: theme.textTheme.titleSmall),
          ),
          _Rule(Icons.schedule, 'Book ${rules.minMinutes} min to ${rules.maxMinutes ~/ 60} h, up to ${rules.horizonDays} days ahead'),
          _Rule(Icons.bookmarks_outlined, 'At most ${rules.maxActivePerUser} upcoming bookings at a time'),
          _Rule(Icons.qr_code, 'Check in from ${rules.checkinEarlyMinutes} min before the start'),
          _Rule(Icons.timer_off_outlined,
              'Not checked in ${rules.checkinGraceMinutes} min after the start? The seat is released'),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.dns_outlined),
            title: const Text('Server'),
            subtitle: Text(session.serverUrl),
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ServerSettingsScreen())),
          ),
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('Log out'),
            onTap: session.logout,
          ),
        ],
      ),
    );
  }
}

class _Rule extends StatelessWidget {
  const _Rule(this.icon, this.text);

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => ListTile(dense: true, leading: Icon(icon), title: Text(text));
}

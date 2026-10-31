import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/bookings_model.dart';
import '../state/session.dart';
import 'admin/admin_rooms_screen.dart';
import 'admin/dashboard_screen.dart';
import 'admin/day_bookings_screen.dart';
import 'my_bookings_screen.dart';
import 'profile_screen.dart';
import 'rooms_screen.dart';
import 'scan_screen.dart';

class _Tab {
  const _Tab(this.label, this.icon, this.selectedIcon, this.page);
  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final Widget page;
}

/// Main screen after login. Students and admins get different tabs.
/// Responsive: bottom NavigationBar on phones, NavigationRail on wide
/// screens (web, desktop, tablets).
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  @override
  void initState() {
    super.initState();
    final bookings = context.read<BookingsModel>();
    bookings.clear();
    if (!context.read<Session>().user!.isAdmin) bookings.refresh();
  }

  void _goTo(int i) => setState(() => _index = i);

  @override
  Widget build(BuildContext context) {
    final isAdmin = context.watch<Session>().user!.isAdmin;
    final tabs = isAdmin
        ? const [
            _Tab('Dashboard', Icons.insights_outlined, Icons.insights, DashboardScreen()),
            _Tab('Bookings', Icons.list_alt_outlined, Icons.list_alt, DayBookingsScreen()),
            _Tab('Rooms', Icons.meeting_room_outlined, Icons.meeting_room, AdminRoomsScreen()),
            _Tab('Profile', Icons.person_outline, Icons.person, ProfileScreen()),
          ]
        : [
            _Tab('Rooms', Icons.event_seat_outlined, Icons.event_seat, RoomsScreen(onBooked: () => _goTo(1))),
            const _Tab('My bookings', Icons.bookmark_border, Icons.bookmark, MyBookingsScreen()),
            _Tab('Check in', Icons.qr_code_scanner, Icons.qr_code_scanner, ScanScreen(onDone: () => _goTo(1))),
            const _Tab('Profile', Icons.person_outline, Icons.person, ProfileScreen()),
          ];

    final wide = MediaQuery.sizeOf(context).width >= 720;
    final body = IndexedStack(index: _index, children: [for (final t in tabs) t.page]);

    if (wide) {
      return Scaffold(
        body: Row(children: [
          NavigationRail(
            selectedIndex: _index,
            onDestinationSelected: _goTo,
            labelType: NavigationRailLabelType.all,
            leading: Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Icon(Icons.event_seat, size: 32, color: Theme.of(context).colorScheme.primary),
            ),
            destinations: [
              for (final t in tabs)
                NavigationRailDestination(icon: Icon(t.icon), selectedIcon: Icon(t.selectedIcon), label: Text(t.label)),
            ],
          ),
          const VerticalDivider(width: 1),
          Expanded(child: body),
        ]),
      );
    }
    return Scaffold(
      body: body,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: _goTo,
        destinations: [
          for (final t in tabs) NavigationDestination(icon: Icon(t.icon), selectedIcon: Icon(t.selectedIcon), label: t.label),
        ],
      ),
    );
  }
}

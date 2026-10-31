import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../api/api_client.dart';
import '../../models/models.dart';
import '../../state/session.dart';
import '../../widgets/common.dart';

/// Librarian's overview: live occupancy, then per-room numbers and the
/// busiest hours over the last 7 days. Every number comes from one SQL
/// aggregate query on the server (GET /api/admin/stats).
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  AdminStats? _stats;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final res = await context.read<Session>().api.get('/admin/stats', query: {'days': '7'});
      setState(() => _stats = AdminStats.fromJson(res));
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        actions: [IconButton(tooltip: 'Refresh', onPressed: _load, icon: const Icon(Icons.refresh))],
      ),
      body: switch ((_stats, _error)) {
        (_, final String err) => ErrorRetry(message: err, onRetry: _load),
        (null, _) => const Center(child: CircularProgressIndicator()),
        (final AdminStats s, _) => RefreshIndicator(onRefresh: _load, child: _Body(stats: s)),
      },
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.stats});

  final AdminStats stats;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final free = stats.seats - stats.inUse - stats.held;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Right now', style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        Wrap(spacing: 12, runSpacing: 12, children: [
          _Tile('In use', '${stats.inUse}', Icons.event_seat, Colors.green),
          _Tile('Waiting check-in', '${stats.held}', Icons.hourglass_top, Colors.orange),
          _Tile('Free', '$free / ${stats.seats}', Icons.event_available, theme.colorScheme.primary),
          _Tile('Students', '${stats.students}', Icons.groups, theme.colorScheme.tertiary),
        ]),
        const SizedBox(height: 24),
        Text('Last ${stats.days} days, by room', style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        for (final r in stats.rooms)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(r.name, style: theme.textTheme.titleSmall),
                const SizedBox(height: 8),
                Wrap(spacing: 16, runSpacing: 4, children: [
                  Text('${r.bookings} bookings'),
                  Text('${r.attended} attended'),
                  Text('${r.noShows} no-shows'),
                  Text('${r.cancelled} cancelled'),
                  Text('${r.hoursUsed} seat-hours used'),
                ]),
                const SizedBox(height: 8),
                Row(children: [
                  const Text('No-show rate '),
                  Expanded(
                    child: LinearProgressIndicator(
                      value: r.noShowRate,
                      minHeight: 8,
                      borderRadius: BorderRadius.circular(4),
                      color: r.noShowRate > 0.25 ? theme.colorScheme.error : Colors.orange,
                    ),
                  ),
                  Text('  ${(r.noShowRate * 100).round()}%'),
                ]),
              ]),
            ),
          ),
        const SizedBox(height: 24),
        Text('Busiest start hours', style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        _HourChart(byHour: stats.byHour),
      ],
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile(this.label, this.value, this.icon, this.color);

  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 160,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(icon, color: color),
            const SizedBox(height: 8),
            Text(value, style: Theme.of(context).textTheme.headlineSmall),
            Text(label),
          ]),
        ),
      ),
    );
  }
}

/// Simple bar chart drawn with plain widgets (no chart package needed).
class _HourChart extends StatelessWidget {
  const _HourChart({required this.byHour});

  final Map<int, int> byHour;

  @override
  Widget build(BuildContext context) {
    if (byHour.isEmpty) return const Text('No bookings yet.');
    final theme = Theme.of(context);
    final hours = [for (var h = 8; h <= 21; h++) h];
    final maxCount = byHour.values.fold<int>(1, (a, b) => a > b ? a : b);
    return SizedBox(
      height: 180,
      child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
        for (final h in hours)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
                if ((byHour[h] ?? 0) > 0) Text('${byHour[h]}', style: theme.textTheme.labelSmall),
                Container(
                  height: 120 * (byHour[h] ?? 0) / maxCount,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                  ),
                ),
                const SizedBox(height: 4),
                Text('$h', style: theme.textTheme.labelSmall),
              ]),
            ),
          ),
      ]),
    );
  }
}

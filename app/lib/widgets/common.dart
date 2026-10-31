import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../api/api_client.dart';

final timeFmt = DateFormat('h:mm a');
final dayFmt = DateFormat('EEE d MMM');

String slotText(DateTime start, DateTime end) => '${dayFmt.format(start)}, ${timeFmt.format(start)} – ${timeFmt.format(end)}';

void showError(BuildContext context, Object error) {
  final message = error is ApiException ? error.message : 'Something went wrong: $error';
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message), behavior: SnackBarBehavior.floating));
}

void showInfo(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message), behavior: SnackBarBehavior.floating));
}

/// Coloured label for a booking status.
class StatusChip extends StatelessWidget {
  const StatusChip(this.status, {super.key});

  final String status;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (label, bg, fg) = switch (status) {
      'booked' => ('Booked', scheme.primaryContainer, scheme.onPrimaryContainer),
      'checked_in' => ('Checked in', Colors.green.shade600, Colors.white),
      'completed' => ('Completed', scheme.secondaryContainer, scheme.onSecondaryContainer),
      'cancelled' => ('Cancelled', scheme.surfaceContainerHighest, scheme.onSurfaceVariant),
      'no_show' => ('No-show, released', scheme.errorContainer, scheme.onErrorContainer),
      _ => (status, scheme.surfaceContainerHighest, scheme.onSurfaceVariant),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Text(label, style: TextStyle(color: fg, fontSize: 12, fontWeight: FontWeight.w600)),
    );
  }
}

/// Full-screen message with a retry button, for load errors.
class ErrorRetry extends StatelessWidget {
  const ErrorRetry({super.key, required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off, size: 48, color: Theme.of(context).colorScheme.error),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            FilledButton.tonal(onPressed: onRetry, child: const Text('Try again')),
          ],
        ),
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 48, color: muted),
          const SizedBox(height: 12),
          Text(text, textAlign: TextAlign.center, style: TextStyle(color: muted)),
        ]),
      ),
    );
  }
}

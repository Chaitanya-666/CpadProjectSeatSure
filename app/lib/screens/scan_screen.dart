import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';

import '../api/api_client.dart';
import '../models/models.dart';
import '../state/bookings_model.dart';
import '../widgets/common.dart';

/// Camera scanning works on Android, iOS and the web. Linux desktop has no
/// scanner plugin, so there (and as a fallback anywhere) the student can
/// type the code printed under the QR.
bool get cameraSupported =>
    kIsWeb ||
    defaultTargetPlatform == TargetPlatform.android ||
    defaultTargetPlatform == TargetPlatform.iOS;

class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key, required this.onDone});

  final VoidCallback onDone;

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  bool _camera = false; // camera starts only when asked, to save battery
  bool _busy = false;
  final _code = TextEditingController();

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _submit(String token) async {
    if (_busy || token.trim().isEmpty) return;
    setState(() {
      _busy = true;
      _camera = false;
    });
    try {
      final booking = await context.read<BookingsModel>().checkin(token.trim());
      if (!mounted) return;
      _code.clear();
      await _showResult(booking);
      widget.onDone();
    } on ApiException catch (e) {
      if (mounted) await _showProblem(e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _showResult(Booking b) => showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      icon: const Icon(Icons.check_circle, color: Colors.green, size: 48),
      title: Text('Checked in at ${b.seatLabel}'),
      content: Text(
        '${b.roomName}\nThe seat is yours until ${timeFmt.format(b.end)}.',
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('OK'),
        ),
      ],
    ),
  );

  Future<void> _showProblem(ApiException e) => showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      icon: Icon(
        Icons.error_outline,
        color: Theme.of(context).colorScheme.error,
        size: 48,
      ),
      title: const Text('Could not check in'),
      content: Text(e.message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('OK'),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final due = context
        .watch<BookingsModel>()
        .upcoming
        .where((b) => b.canCheckIn(DateTime.now()))
        .toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Check in')),
      // Phone-width column even on wide screens: a full-width square camera
      // box on a desktop browser was ~1700 px tall and pushed the code field
      // off-screen (found on the live web build, 2026-10-31).
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (due.isNotEmpty)
                Card(
                  color: theme.colorScheme.primaryContainer,
                  child: ListTile(
                    leading: const Icon(Icons.timer_outlined),
                    title: Text(
                      'Seat ${due.first.seatLabel} · ${due.first.roomName}',
                    ),
                    subtitle: Text(
                      'Scan before ${timeFmt.format(due.first.checkinDeadline)}',
                    ),
                  ),
                )
              else
                const Text(
                  'Go to your seat and scan the QR code stuck on the desk.',
                ),
              const SizedBox(height: 16),
              if (cameraSupported) ...[
                if (_camera)
                  AspectRatio(
                    aspectRatio: 1,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: MobileScanner(
                        onDetect: (capture) {
                          final value = capture.barcodes.firstOrNull?.rawValue;
                          if (value != null) _submit(value);
                        },
                        errorBuilder: (context, error) => Center(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Text(
                              error.errorCode ==
                                      MobileScannerErrorCode.permissionDenied
                                  ? 'Camera permission is blocked. Allow the camera for this app '
                                        '(browser: the camera icon in the address bar), or type the code below.'
                                  : 'Camera unavailable (${error.errorCode.name}). Type the code below instead.',
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                      ),
                    ),
                  )
                else
                  FilledButton.icon(
                    onPressed: _busy
                        ? null
                        : () => setState(() => _camera = true),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(56),
                    ),
                    icon: const Icon(Icons.qr_code_scanner),
                    label: const Text('Scan seat QR'),
                  ),
                if (_camera)
                  TextButton(
                    onPressed: () => setState(() => _camera = false),
                    child: const Text('Stop camera'),
                  ),
                const SizedBox(height: 24),
                const Row(
                  children: [
                    Expanded(child: Divider()),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8),
                      child: Text('or'),
                    ),
                    Expanded(child: Divider()),
                  ],
                ),
                const SizedBox(height: 16),
              ],
              TextField(
                controller: _code,
                decoration: const InputDecoration(
                  labelText: 'Code printed under the QR',
                  hintText: 'seat_...',
                  border: OutlineInputBorder(),
                ),
                onSubmitted: _submit,
              ),
              const SizedBox(height: 12),
              FilledButton.tonal(
                onPressed: _busy ? null : () => _submit(_code.text),
                child: _busy
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Check in with code'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

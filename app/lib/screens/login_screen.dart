import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/session.dart';
import '../widgets/common.dart';
import 'server_settings_screen.dart';

/// Log in or create a student account (one screen, toggled).
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _registering = false;
  bool _busy = false;
  bool _hide = true;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    final session = context.read<Session>();
    try {
      if (_registering) {
        await session.register(_name.text.trim(), _email.text.trim(), _password.text);
      } else {
        await session.login(_email.text.trim(), _password.text);
      }
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        actions: [
          IconButton(
            tooltip: 'Server settings',
            icon: const Icon(Icons.dns_outlined),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ServerSettingsScreen())),
          ),
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Form(
              key: _form,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Icon(Icons.event_seat, size: 64, color: theme.colorScheme.primary),
                  const SizedBox(height: 8),
                  Text('SeatSure', textAlign: TextAlign.center, style: theme.textTheme.headlineMedium),
                  Text(
                    'Book a library seat, check in by QR',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 32),
                  if (_registering) ...[
                    TextFormField(
                      controller: _name,
                      decoration: const InputDecoration(labelText: 'Full name', border: OutlineInputBorder()),
                      textInputAction: TextInputAction.next,
                      validator: (v) => (v ?? '').trim().length < 2 ? 'Enter your name' : null,
                    ),
                    const SizedBox(height: 12),
                  ],
                  TextFormField(
                    controller: _email,
                    decoration: const InputDecoration(labelText: 'Email', border: OutlineInputBorder()),
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    autofillHints: const [AutofillHints.email],
                    validator: (v) => (v ?? '').contains('@') ? null : 'Enter a valid email',
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _password,
                    obscureText: _hide,
                    decoration: InputDecoration(
                      labelText: 'Password',
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        icon: Icon(_hide ? Icons.visibility : Icons.visibility_off),
                        onPressed: () => setState(() => _hide = !_hide),
                      ),
                    ),
                    onFieldSubmitted: (_) => _submit(),
                    validator: (v) {
                      if ((v ?? '').isEmpty) return 'Enter your password';
                      if (_registering && v!.length < 8) return 'At least 8 characters';
                      return null;
                    },
                  ),
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: _busy ? null : _submit,
                    style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                    child: _busy
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                        : Text(_registering ? 'Create account' : 'Log in'),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: _busy ? null : () => setState(() => _registering = !_registering),
                    child: Text(_registering ? 'Have an account? Log in' : 'New here? Create a student account'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

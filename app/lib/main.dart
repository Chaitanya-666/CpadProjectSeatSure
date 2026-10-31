import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'screens/home_shell.dart';
import 'screens/login_screen.dart';
import 'state/bookings_model.dart';
import 'state/session.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  final session = Session(prefs);
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: session),
        ChangeNotifierProvider(create: (_) => BookingsModel(session.api)),
      ],
      child: const SeatSureApp(),
    ),
  );
  session.restore();
}

class SeatSureApp extends StatelessWidget {
  const SeatSureApp({super.key});

  static const seed = Color(0xFF00796B); // teal

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SeatSure',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorSchemeSeed: seed, brightness: Brightness.light),
      darkTheme: ThemeData(colorSchemeSeed: seed, brightness: Brightness.dark),
      home: const _Gate(),
    );
  }
}

/// Shows a splash while the saved session is checked, then the login screen
/// or the home screen. Rebuilds whenever Session calls notifyListeners().
class _Gate extends StatelessWidget {
  const _Gate();

  @override
  Widget build(BuildContext context) {
    final session = context.watch<Session>();
    if (session.restoring) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return session.loggedIn ? HomeShell(key: ValueKey(session.user!.id)) : const LoginScreen();
  }
}

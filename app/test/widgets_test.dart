import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:seatsure/models/models.dart';
import 'package:seatsure/screens/login_screen.dart';
import 'package:seatsure/screens/my_bookings_screen.dart';
import 'package:seatsure/state/bookings_model.dart';
import 'package:seatsure/state/session.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'models_test.dart' show bookingJson;

Future<Widget> harness(Widget child) async {
  SharedPreferences.setMockInitialValues({});
  final session = Session(await SharedPreferences.getInstance());
  return MultiProvider(
    providers: [
      ChangeNotifierProvider.value(value: session),
      ChangeNotifierProvider(create: (_) => BookingsModel(session.api)),
    ],
    child: MaterialApp(home: child),
  );
}

void main() {
  testWidgets('login validates before calling the server', (tester) async {
    await tester.pumpWidget(await harness(const LoginScreen()));
    await tester.tap(find.widgetWithText(FilledButton, 'Log in'));
    await tester.pump();
    expect(find.text('Enter a valid email'), findsOneWidget);
    expect(find.text('Enter your password'), findsOneWidget);
  });

  testWidgets('switching to sign-up shows the name field and the 8-character rule', (tester) async {
    await tester.pumpWidget(await harness(const LoginScreen()));
    await tester.tap(find.text('New here? Create a student account'));
    await tester.pump();
    expect(find.widgetWithText(TextFormField, 'Full name'), findsOneWidget);
    await tester.enterText(find.widgetWithText(TextFormField, 'Email'), 'a@b.com');
    await tester.enterText(find.widgetWithText(TextFormField, 'Password'), 'short');
    await tester.tap(find.widgetWithText(FilledButton, 'Create account'));
    await tester.pump();
    expect(find.text('At least 8 characters'), findsOneWidget);
  });

  testWidgets('a booking inside its check-in window says "Check in now" and can be cancelled', (tester) async {
    final booking = Booking.fromJson(bookingJson(start: DateTime.now().subtract(const Duration(minutes: 2))));
    await tester.pumpWidget(await harness(Scaffold(body: BookingCard(booking: booking))));
    expect(find.text('Seat A1 · Central Reading Hall'), findsOneWidget);
    expect(find.textContaining('Check in now!'), findsOneWidget);
    expect(find.text('Cancel booking'), findsOneWidget);
    expect(find.text('Booked'), findsOneWidget);
  });

  testWidgets('a no-show booking shows the released status and no actions', (tester) async {
    final booking = Booking.fromJson(
      bookingJson(start: DateTime.now().subtract(const Duration(hours: 3)), status: 'no_show'),
    );
    await tester.pumpWidget(await harness(Scaffold(body: BookingCard(booking: booking))));
    expect(find.text('No-show, released'), findsOneWidget);
    expect(find.byType(TextButton), findsNothing);
    expect(find.byType(FilledButton), findsNothing);
  });
}

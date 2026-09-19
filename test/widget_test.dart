import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whynot_mobile/app/app_routes.dart';
import 'package:whynot_mobile/app/whynot_app.dart';

/// Verifies the main authentication flow using the real route configuration.
void main() {
  testWidgets('renders login and navigates through the account flow', (
    tester,
  ) async {
    await tester.pumpWidget(const WhyNotApp());
    await tester.pumpAndSettle();

    expect(find.text('WHYNOT'), findsOneWidget);
    expect(find.text('Create an account'), findsOneWidget);

    await tester.ensureVisible(find.text('Create an account'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Create an account'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Preferred Category'));
    await tester.pumpAndSettle();
    expect(find.text('Preferred Category'), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Log in'));
    await tester.pumpAndSettle();
    expect(find.text('Good Morning, Juliana'), findsOneWidget);
  });

  testWidgets('opens the admin dashboard from login', (tester) async {
    await tester.pumpWidget(const WhyNotApp());
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Admin login'));
    await tester.tap(find.text('Admin login'));
    await tester.pumpAndSettle();

    expect(find.text('WHYNOT ADMIN'), findsOneWidget);
    expect(find.text('Saved products'), findsOneWidget);
  });

  testWidgets('opens edit profile before change password', (tester) async {
    await tester.pumpWidget(const WhyNotApp());
    await tester.pumpAndSettle();

    final navigator = tester.state<NavigatorState>(find.byType(Navigator));
    navigator.pushNamed(AppRoutes.profile);
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Edit Profile'));
    await tester.tap(find.text('Edit Profile'));
    await tester.pumpAndSettle();

    expect(find.text('Edit Profile'), findsOneWidget);
    expect(find.text('Preferred Category'), findsOneWidget);
    expect(find.text('Save changes'), findsOneWidget);

    await tester.ensureVisible(find.text('Change password'));
    await tester.tap(find.text('Change password'));
    await tester.pumpAndSettle();

    expect(find.text('Change Password'), findsOneWidget);
  });
}

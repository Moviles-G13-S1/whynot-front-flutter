import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whynot_mobile/app/app_routes.dart';
import 'package:whynot_mobile/app/whynot_app.dart';
import 'package:whynot_mobile/features/admin/application/admin_access.dart';
import 'package:whynot_mobile/features/admin/presentation/admin_route_guard.dart';

void main() {
  test('recognizes only an exact admin true claim', () {
    expect(AdminAuthorization.hasAdminClaim({'admin': true}), isTrue);
    expect(AdminAuthorization.hasAdminClaim({'admin': false}), isFalse);
    expect(AdminAuthorization.hasAdminClaim({'admin': 'true'}), isFalse);
    expect(AdminAuthorization.hasAdminClaim(null), isFalse);
  });

  testWidgets('login no longer exposes a direct admin bypass', (tester) async {
    await tester.pumpWidget(const WhyNotApp());
    await tester.pumpAndSettle();

    expect(find.text('WHYNOT'), findsOneWidget);
    expect(find.text('Admin login'), findsNothing);
  });

  testWidgets('admin route renders after an authorized claim check', (
    tester,
  ) async {
    await tester.pumpWidget(
      WhyNotApp(adminAccessResolver: () async => AdminAccess.admin),
    );
    await tester.pumpAndSettle();

    final navigator = tester.state<NavigatorState>(find.byType(Navigator));
    navigator.pushNamed(AppRoutes.adminDashboard);
    await tester.pumpAndSettle();

    expect(find.text('WHYNOT ADMIN'), findsOneWidget);
    expect(find.text('Saved products'), findsOneWidget);
  });

  testWidgets('guard redirects signed-out users to login', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        initialRoute: '/protected',
        routes: {
          AppRoutes.login: (_) => const Scaffold(body: Text('Login route')),
          AppRoutes.home: (_) => const Scaffold(body: Text('Home route')),
          '/protected': (_) => AdminRouteGuard(
            resolveAccess: () async => AdminAccess.signedOut,
            child: const Text('Protected content'),
          ),
        },
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Login route'), findsOneWidget);
    expect(find.text('Protected content'), findsNothing);
  });

  testWidgets('guard redirects regular users to home', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        initialRoute: '/protected',
        routes: {
          AppRoutes.login: (_) => const Scaffold(body: Text('Login route')),
          AppRoutes.home: (_) => const Scaffold(body: Text('Home route')),
          '/protected': (_) => AdminRouteGuard(
            resolveAccess: () async => AdminAccess.regularUser,
            child: const Text('Protected content'),
          ),
        },
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Home route'), findsOneWidget);
    expect(find.text('Protected content'), findsNothing);
  });
}

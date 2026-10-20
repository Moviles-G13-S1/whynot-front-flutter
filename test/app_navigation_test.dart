import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whynot_mobile/app/app_navigation.dart';
import 'package:whynot_mobile/app/app_routes.dart';

void main() {
  testWidgets('Add opens the sheet and Continue navigates to new product', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        routes: {
          AppRoutes.newProduct: (_) =>
              const Scaffold(body: Text('New product screen')),
        },
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () =>
                  AppNavigation.select(context, 2, currentIndex: 0),
              child: const Text('Add'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();
    expect(find.text('Add a new item'), findsOneWidget);

    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(find.text('New product screen'), findsOneWidget);
    expect(find.text('Add a new item'), findsNothing);
  });
}

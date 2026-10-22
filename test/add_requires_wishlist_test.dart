import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whynot_mobile/app/app_routes.dart';
import 'package:whynot_mobile/app/dependencies_scope.dart';
import 'package:whynot_mobile/models/category.dart';
import 'package:whynot_mobile/models/wishlist.dart';
import 'package:whynot_mobile/views/widgets/app_bottom_navigation.dart';

import 'fakes/app_dependencies_fixture.dart';

void main() {
  testWidgets('shows an alert when the user has no wishlists', (tester) async {
    final dependencies = createTestDependencies(
      signedIn: true,
      categories: const [Category(id: 'fashion', name: 'Fashion')],
    );

    await tester.pumpWidget(
      DependenciesScope(
        dependencies: dependencies,
        child: MaterialApp(
          routes: {
            AppRoutes.newWishlist: (_) =>
                const Scaffold(body: Text('Create wishlist screen')),
            AppRoutes.newProductManual: (_) =>
                const Scaffold(body: Text('New product screen')),
          },
          home: const Scaffold(
            bottomNavigationBar: AppBottomNavigation(selectedIndex: 0),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();

    expect(find.text('Create a wishlist first'), findsOneWidget);
    expect(
      find.text('You need at least one wishlist before adding products.'),
      findsOneWidget,
    );
    expect(find.text('New product screen'), findsNothing);

    // Cancel closes the alert without navigating.
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(find.text('Create a wishlist first'), findsNothing);
    expect(find.text('New product screen'), findsNothing);

    // The user can open the alert again and create a wishlist.
    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Create Wishlist'));
    await tester.pumpAndSettle();

    expect(find.text('Create wishlist screen'), findsOneWidget);
    expect(find.text('New product screen'), findsNothing);
  });

  testWidgets('opens the product form when a wishlist exists', (tester) async {
    final dependencies = createTestDependencies(
      signedIn: true,
      categories: const [Category(id: 'fashion', name: 'Fashion')],
      wishlists: const [
        Wishlist(
          id: 'wishlist-1',
          ownerId: 'test-user',
          categoryId: 'fashion',
          imageUrl: '',
        ),
      ],
    );

    await tester.pumpWidget(
      DependenciesScope(
        dependencies: dependencies,
        child: MaterialApp(
          routes: {
            AppRoutes.newWishlist: (_) =>
                const Scaffold(body: Text('Create wishlist screen')),
            AppRoutes.newProductManual: (_) =>
                const Scaffold(body: Text('New product screen')),
          },
          home: const Scaffold(
            bottomNavigationBar: AppBottomNavigation(selectedIndex: 0),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();

    expect(find.text('New product screen'), findsOneWidget);
    expect(find.text('Create a wishlist first'), findsNothing);
  });
}

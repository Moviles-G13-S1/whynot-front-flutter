import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whynot_mobile/app/app_routes.dart';
import 'package:whynot_mobile/app/whynot_app.dart';
import 'package:whynot_mobile/features/admin/application/admin_access.dart';
import 'package:whynot_mobile/features/admin/presentation/admin_route_guard.dart';
import 'package:whynot_mobile/features/admin/presentation/saved_products_screen.dart';
import 'package:whynot_mobile/features/admin/presentation/widgets/admin_components.dart';
import 'package:whynot_mobile/features/products/domain/product.dart';
import 'package:whynot_mobile/features/profile/domain/user_profile.dart';
import 'package:whynot_mobile/shared/domain/category.dart';
import 'package:whynot_mobile/shared/domain/city.dart';
import 'package:whynot_mobile/shared/widgets/city_selector.dart';

import 'fakes/app_dependencies_fixture.dart';

void main() {
  testWidgets('city search accepts names without accents', (tester) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    String? selectedId;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CitySelector(
            cities: const [
              City(id: 'bogota', name: 'Bogotá'),
              City(id: 'medellin', name: 'Medellín'),
            ],
            controller: controller,
            selectedId: null,
            onSelected: (id) => selectedId = id,
          ),
        ),
      ),
    );

    await tester.enterText(find.byType(TextField), 'Bogota');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bogotá').last);
    await tester.pumpAndSettle();

    expect(selectedId, 'bogota');
    expect(controller.text, 'Bogotá');
  });

  test('recognizes only an exact admin true claim', () {
    expect(AdminAuthorization.hasAdminClaim({'admin': true}), isTrue);
    expect(AdminAuthorization.hasAdminClaim({'admin': false}), isFalse);
    expect(AdminAuthorization.hasAdminClaim({'admin': 'true'}), isFalse);
    expect(AdminAuthorization.hasAdminClaim(null), isFalse);
  });

  testWidgets('login no longer exposes a direct admin bypass', (tester) async {
    await tester.pumpWidget(WhyNotApp(dependencies: createTestDependencies()));
    await tester.pumpAndSettle();

    expect(find.text('WHYNOT'), findsOneWidget);
    expect(find.text('Admin login'), findsNothing);
  });

  testWidgets('admin route renders after an authorized claim check', (
    tester,
  ) async {
    await tester.pumpWidget(
      WhyNotApp(
        dependencies: createTestDependencies(),
        adminAccessResolver: () async => AdminAccess.admin,
      ),
    );
    await tester.pumpAndSettle();

    final navigator = tester.state<NavigatorState>(find.byType(Navigator));
    navigator.pushNamed(AppRoutes.adminDashboard);
    await tester.pumpAndSettle();

    expect(find.text('WHYNOT ADMIN'), findsOneWidget);
    expect(find.text('Saved products'), findsOneWidget);
  });

  testWidgets('admin screens count existing products', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final products = [
      const Product(
        id: 'one',
        ownerId: 'alice',
        wishlistId: 'list-a',
        categoryId: 'fashion',
        name: 'Jacket',
        brand: 'Brand',
        price: 10,
        imageUrl: '',
        productUrl: '',
        purchased: false,
      ),
      Product(
        id: 'two',
        ownerId: 'alice',
        wishlistId: 'list-a',
        categoryId: 'fashion',
        name: 'Shoes',
        brand: 'Brand',
        price: 20,
        imageUrl: '',
        productUrl: '',
        purchased: true,
        purchasedAt: DateTime.now(),
      ),
      const Product(
        id: 'three',
        ownerId: 'bob',
        wishlistId: 'list-b',
        categoryId: 'beauty',
        name: 'Cream',
        brand: 'Brand',
        price: 30,
        imageUrl: '',
        productUrl: '',
        purchased: false,
      ),
    ];

    await tester.pumpWidget(
      WhyNotApp(
        dependencies: createTestDependencies(
          products: products,
          profiles: const [
            UserProfile(
              id: 'alice',
              name: 'Alice',
              email: 'a@example.com',
              gender: 'Female',
              age: 22,
              preferredCategoryId: 'fashion',
            ),
            UserProfile(
              id: 'bob',
              name: 'Bob',
              email: 'b@example.com',
              gender: 'Male',
              age: 25,
              preferredCategoryId: 'beauty',
            ),
            UserProfile(
              id: 'carol',
              name: 'Carol',
              email: 'c@example.com',
              gender: 'Female',
              age: 30,
              preferredCategoryId: 'fashion',
            ),
          ],
        ),
        adminAccessResolver: () async => AdminAccess.admin,
      ),
    );
    await tester.pumpAndSettle();

    final navigator = tester.state<NavigatorState>(find.byType(Navigator));
    navigator.pushNamed(AppRoutes.adminSavedProducts);
    await tester.pumpAndSettle();
    expect(find.text('3'), findsOneWidget);
    expect(find.text('2 active users'), findsOneWidget);
    expect(find.text('Users with 0 products'), findsOneWidget);
    expect(
      tester
          .widget<SavedProductsZeroUsersCard>(
            find.byType(SavedProductsZeroUsersCard),
          )
          .count,
      1,
    );
    expect(find.text('1.5'), findsOneWidget);
    expect(find.text('Distribution'), findsOneWidget);
    final distribution = tester.widget<SavedProductsDistributionCard>(
      find.byType(SavedProductsDistributionCard),
    );
    expect(distribution.bars.first.valueLabel, '100%');
    expect(distribution.bars.first.value, 1);

    navigator.pushNamed(AppRoutes.adminPurchasedProducts);
    await tester.pumpAndSettle();
    expect(find.text('PURCHASED BY MONTH'), findsOneWidget);
    expect(find.text('fashion'), findsOneWidget);
    expect(find.text('1'), findsOneWidget);
    await tester.tap(find.text('12 months'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<AdminSegmentedControl>(find.byType(AdminSegmentedControl))
          .selectedIndex,
      1,
    );
    await tester.tap(find.text('24 months'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<AdminSegmentedControl>(find.byType(AdminSegmentedControl))
          .selectedIndex,
      2,
    );
  });

  testWidgets('demographic chart uses profiles and Firestore categories', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      WhyNotApp(
        dependencies: createTestDependencies(
          categories: const [
            Category(id: 'technology', name: 'Technology'),
            Category(id: 'beauty', name: 'Beauty'),
          ],
          products: const [
            Product(
              id: 'one',
              ownerId: 'alice',
              wishlistId: 'a',
              categoryId: 'technology',
              name: 'Phone',
              brand: 'Brand',
              price: 1,
              imageUrl: '',
              productUrl: '',
              purchased: false,
            ),
          ],
          profiles: const [
            UserProfile(
              id: 'alice',
              name: 'Alice',
              email: 'a@example.com',
              gender: 'Female',
              age: 22,
              preferredCategoryId: 'beauty',
              cityId: 'bogota',
            ),
          ],
        ),
        adminAccessResolver: () async => AdminAccess.admin,
      ),
    );
    await tester.pumpAndSettle();
    tester
        .state<NavigatorState>(find.byType(Navigator))
        .pushNamed(AppRoutes.adminDemographicProfile);
    await tester.pumpAndSettle();

    expect(find.text('Technology'), findsOneWidget);
    expect(find.text('Bogotá'), findsOneWidget);
    expect(find.text('Women 100%'), findsOneWidget);
    expect(
      find.text('1 user with a current product in Technology'),
      findsOneWidget,
    );

    await tester.tap(find.text('Beauty'));
    await tester.pumpAndSettle();
    expect(
      find.text('0 users with a current product in Beauty'),
      findsOneWidget,
    );
  });

  testWidgets('purchase chart fits all Firestore categories on a phone', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    const categories = [
      'fashion',
      'beauty',
      'technology',
      'home',
      'accessories',
      'travel',
      'gifts',
      'other',
    ];
    final products = [
      for (final category in categories)
        Product(
          id: category,
          ownerId: 'owner',
          wishlistId: category,
          categoryId: category,
          name: 'Product',
          brand: 'Brand',
          price: 1,
          imageUrl: '',
          productUrl: '',
          purchased: true,
          purchasedAt: DateTime.now(),
        ),
    ];
    await tester.pumpWidget(
      WhyNotApp(
        dependencies: createTestDependencies(products: products),
        adminAccessResolver: () async => AdminAccess.admin,
      ),
    );
    await tester.pumpAndSettle();
    tester
        .state<NavigatorState>(find.byType(Navigator))
        .pushNamed(AppRoutes.adminPurchasedProducts);
    await tester.pumpAndSettle();

    expect(find.text('PURCHASED BY MONTH'), findsOneWidget);
    expect(find.text('technology'), findsOneWidget);
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

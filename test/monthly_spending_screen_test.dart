import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whynot_mobile/app/app_routes.dart';
import 'package:whynot_mobile/app/dependencies_scope.dart';
import 'package:whynot_mobile/app/whynot_theme.dart';
import 'package:whynot_mobile/controllers/connectivity_status.dart';
import 'package:whynot_mobile/controllers/monthly_spending_controller.dart';
import 'package:whynot_mobile/models/monthly_spending.dart';
import 'package:whynot_mobile/models/product.dart';
import 'package:whynot_mobile/views/screens/category_spending_detail_screen.dart';
import 'package:whynot_mobile/views/screens/monthly_spending_screen.dart';
import 'package:whynot_mobile/views/screens/purchases_screen.dart';
import 'fakes/app_dependencies_fixture.dart';
import 'monthly_spending_test.dart'
    show purchase, MemorySpendingStore, immediateCache;

void main() {
  testWidgets(
    'Purchases button opens Monthly Spending even with no purchased items',
    (tester) async {
      final deps = createTestDependencies(signedIn: true);
      await tester.pumpWidget(
        DependenciesScope(
          dependencies: deps,
          child: MaterialApp(
            home: const PurchasesScreen(),
            routes: {
              AppRoutes.monthlySpending: (_) =>
                  const Scaffold(body: Text('Summary destination')),
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Monthly Spending'));
      await tester.pumpAndSettle();
      expect(find.text('Summary destination'), findsOneWidget);
    },
  );

  testWidgets(
    'summary and category drill-down share totals offline and update on server replacement',
    (tester) async {
      tester.view.resetPhysicalSize();
      tester.view.physicalSize = const Size(402, 874);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final network = ConnectivityStatus(observe: false)
        ..setStatus(NetworkStatus.offline);
      addTearDown(network.dispose);
      final store = MemorySpendingStore();
      store.values['u'] = SpendingSnapshot(
        syncedAt: DateTime.utc(2026, 11, 28),
        purchases: [
          SpendingPurchase.fromProduct(
            purchase('coat', price: 120, date: DateTime.utc(2026, 11, 15)),
          )!,
          SpendingPurchase.fromProduct(
            purchase(
              'phone',
              price: 80,
              category: 'technology',
              date: DateTime.utc(2026, 11, 20),
            ),
          )!,
          SpendingPurchase.fromProduct(
            purchase('old', date: DateTime.utc(2026, 10, 20)),
          )!,
          SpendingPurchase.fromProduct(purchase('undated'))!,
        ],
      );
      final events = StreamController<OwnerProducts>.broadcast();
      final c = MonthlySpendingController(
        ownerId: 'u',
        currentUserId: () => 'u',
        watchProducts: () => events.stream,
        connectivity: network,
        store: store,
        cache: immediateCache(),
        now: () => DateTime.utc(2026, 11, 28, 12),
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: WhyNotTheme.data,
          home: MonthlySpendingScreen(controller: c),
          routes: {
            AppRoutes.categorySpendingDetail: (_) =>
                const CategorySpendingDetailScreen(),
          },
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('\$200.00'), findsOneWidget);
      expect(find.text('You are offline'), findsOneWidget);
      expect(c.undatedCount, 1);
      await tester.ensureVisible(find.text('Fashion'));
      await tester.tap(find.text('Fashion'));
      await tester.pumpAndSettle();
      expect(find.text('Category Spending Detail'), findsOneWidget);
      expect(find.text('\$120.00'), findsNWidgets(2));
      expect(find.text('Product coat'), findsOneWidget);
      expect(find.text('You are offline'), findsOneWidget);
      await tester.runAsync(() async {
        network.setStatus(NetworkStatus.available);
        // Stream cancellation completes through the real Dart event loop.
        await Future<void>.delayed(Duration.zero);
      });
      await tester.pumpAndSettle();
      expect(events.hasListener, isTrue);
      await tester.runAsync(() async {
        final updated = Completer<void>();
        void changed() {
          if (c.summary?.count == 0 && !c.calculating && !updated.isCompleted) {
            updated.complete();
          }
        }
        c.addListener(changed);
        events.add(const OwnerProducts(products: []));
        await updated.future.timeout(const Duration(seconds: 3));
        c.removeListener(changed);
      });
      await tester.pumpAndSettle();
      expect(c.summary!.count, 0);
      expect(
        find.text('No purchased products in this category for this month.'),
        findsOneWidget,
      );
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('\$0.00'), findsOneWidget);
      expect(find.text('No purchases this month'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await events.close();
    },
  );

  testWidgets('offline first visit does not claim zero spending', (
    tester,
  ) async {
    final network = ConnectivityStatus(observe: false)
      ..setStatus(NetworkStatus.offline);
    addTearDown(network.dispose);
    final c = MonthlySpendingController(
      ownerId: 'u',
      currentUserId: () => 'u',
      watchProducts: () => const Stream.empty(),
      connectivity: network,
      store: MemorySpendingStore(),
      cache: immediateCache(),
    );
    await tester.pumpWidget(
      MaterialApp(home: MonthlySpendingScreen(controller: c)),
    );
    await tester.pumpAndSettle();
    expect(find.text('Your summary is not available yet'), findsOneWidget);
    expect(find.text('\$0.00'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}

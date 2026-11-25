import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:whynot_mobile/app/whynot_app.dart';
import 'package:whynot_mobile/controllers/connectivity_status.dart';
import 'package:whynot_mobile/controllers/recommendation_controller.dart';
import 'package:whynot_mobile/infrastructure/repositories/sqlite_recent_recommendation_store.dart';
import 'package:whynot_mobile/infrastructure/storage/whynot_local_database.dart';
import 'package:whynot_mobile/models/auth_user.dart';
import 'package:whynot_mobile/models/catalog_product_details.dart';
import 'package:whynot_mobile/models/product_recommendation.dart';
import 'package:whynot_mobile/models/recent_recommendation.dart';
import 'package:whynot_mobile/models/recommendation_catalog_item.dart';
import 'package:whynot_mobile/models/repositories/recent_recommendation_store.dart';
import 'package:whynot_mobile/models/user_profile.dart';
import 'package:whynot_mobile/models/wishlist.dart';
import 'package:whynot_mobile/views/screens/recently_viewed_screen.dart';
import 'package:whynot_mobile/views/widgets/form_controls.dart';

import 'fakes/app_dependencies_fixture.dart';
import 'fakes/in_memory_recommendation_repository.dart';
import 'fakes/in_memory_repositories.dart';

const _alice = AuthUser(id: 'alice', email: 'alice@example.com');
const _bob = AuthUser(id: 'bob', email: 'bob@example.com');
const _item = RecommendationCatalogItem(
  sourceProductId: 'coat',
  name: 'Coat from catalog',
  brand: 'Studio',
  price: 20000,
  imageUrl: '',
  categoryId: 'fashion',
  reason: 'A similar user bought this.',
);

ProductRecommendation _recommendation(String event, {String name = 'Coat'}) =>
    ProductRecommendation(
      recommendationEventId: event,
      name: name,
      brand: 'Studio',
      price: 20000,
      imageUrl: '',
      productUrl: '',
      categoryId: 'fashion',
      reason: 'A similar user bought this.',
    );

RecentRecommendation _entry(String source, String name) => RecentRecommendation(
  sourceProductId: source,
  details: CatalogProductDetails.fromRecommendation(
    _recommendation('discarded', name: name),
  ),
  openedAt: DateTime.utc(2026, 11, 25),
);

class _Catalog extends InMemoryRecommendationRepository {
  int opens = 0;
  int compactOpens = 0;
  int catalogCalls = 0;
  Future<ProductRecommendation>? openResult;

  @override
  Future<List<RecommendationCatalogItem>> getCatalog() async {
    catalogCalls++;
    return const [];
  }

  @override
  Future<ProductRecommendation> openCatalogItem(String sourceProductId) async {
    opens++;
    return await openResult ?? _recommendation('backend-$opens');
  }

  @override
  Future<String> createCatalogEvent(String sourceProductId) async =>
      'compact-${++compactOpens}';
}

// Widget timing uses an immediate local store. The controller and persistence
// cases above the widget exercise use the real FFI implementation.
class _WidgetHistory implements RecentRecommendationStore {
  final _entries = <String, RecentRecommendation>{};
  int _order = 0;

  @override
  Future<void> clear(String userId) async => _entries.remove(userId);

  @override
  Future<List<RecentRecommendation>> read(String userId) async => [
    ?_entries[userId],
  ];

  @override
  Future<int> record(String userId, RecentRecommendation entry) async {
    _entries[userId] = entry;
    return ++_order;
  }

  @override
  Future<void> refreshDetails(
    String userId,
    String sourceProductId,
    int openOrder,
    CatalogProductDetails details,
  ) async {
    final entry = _entries[userId];
    if (entry?.sourceProductId != sourceProductId || _order != openOrder) {
      return;
    }
    _entries[userId] = RecentRecommendation(
      sourceProductId: sourceProductId,
      details: details,
      openedAt: entry!.openedAt,
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(sqfliteFfiInit);
  late String path;
  late WhyNotLocalDatabase db;
  late SqliteRecentRecommendationStore store;
  late InMemoryAuthRepository auth;
  late _Catalog catalog;
  late ConnectivityStatus connectivity;

  WhyNotLocalDatabase openOwner() =>
      WhyNotLocalDatabase(factory: databaseFactoryFfi, databasePath: path);

  RecommendationController createController() => RecommendationController(
    recommendationRepository: catalog,
    authRepository: auth,
    connectivity: connectivity,
    recentRecommendations: store,
  );

  setUp(() async {
    final directory = await Directory.systemTemp.createTemp('whynot-history-');
    path = '${directory.path}/whynot_product_drafts.db';
    db = openOwner();
    store = SqliteRecentRecommendationStore(db);
    auth = InMemoryAuthRepository(user: _alice);
    catalog = _Catalog();
    connectivity = ConnectivityStatus(observe: false);
    addTearDown(() async {
      await db.close();
      await directory.delete(recursive: true);
      connectivity.dispose();
    });
  });

  test(
    'recovers SQLite history after recreation and gates Save offline',
    () async {
      final first = createController();
      final recorded = first.historyChanges.first;
      final opened = first.beginCatalogOpen(_item);
      expect(
        (await opened.recommendation).value?.recommendationEventId,
        'backend-1',
      );
      await recorded;
      await db.close();

      db = openOwner();
      store = SqliteRecentRecommendationStore(db);
      connectivity.setStatus(NetworkStatus.offline);
      final restarted = createController();
      final offlineHistory = await restarted.readRecentRecommendations();
      expect(offlineHistory.single.details.name, 'Coat');
      expect(restarted.staleCatalog, isNull);
      expect(restarted.isCatalogProductCached('coat'), isFalse);
      final touched = restarted.historyChanges.first;
      final offline = await restarted.beginRecentOpen('coat');
      expect(offline.fromHistory, isTrue);
      expect(offline.preview.name, 'Coat');
      expect((await offline.recommendation).value, isNull);
      await touched;
      expect(catalog.opens, 1);
      expect(catalog.catalogCalls, 0);

      await expectLater(
        restarted.saveRecommendation(
          recommendation: offline.preview.withEvent(''),
          wishlistId: 'wishlist',
        ),
        throwsStateError,
      );
      expect(catalog.saves, isEmpty);

      connectivity.setStatus(NetworkStatus.available);
      await expectLater(
        restarted.saveRecommendation(
          recommendation: offline.preview.withEvent(''),
          wishlistId: 'wishlist',
        ),
        throwsStateError,
      );
      final refreshed = restarted.historyChanges.first;
      final fresh = await restarted.retryCatalogOpen(offline);
      expect(fresh.recommendationEventId, 'backend-2');
      expect(catalog.compactOpens, 0);
      await refreshed;
      await restarted.saveRecommendation(
        recommendation: fresh,
        wishlistId: 'wishlist',
      );
      expect(catalog.saves.single.recommendationEventId, 'backend-2');
      expect(catalog.homeEvents, isEmpty);
    },
  );

  test(
    'a missing entry, sign-out and switches cannot expose another UID',
    () async {
      await store.record(_alice.id, _entry('coat', 'Alice coat'));
      await store.record(_bob.id, _entry('coat', 'Bob coat'));
      final controller = createController();
      connectivity.setStatus(NetworkStatus.offline);

      final touched = controller.historyChanges.first;
      final previous = await controller.beginRecentOpen('coat');
      expect(previous.preview.name, 'Alice coat');
      await touched;
      final oldRead = controller.readRecentRecommendations();
      await auth.signOut();
      controller.handleAuthChange();
      expect(await oldRead, isEmpty);
      expect(await controller.readRecentRecommendations(), isEmpty);
      expect(controller.isCurrentCatalogOpen(previous), isFalse);
      await expectLater(
        controller.retryCatalogOpen(previous),
        throwsStateError,
      );

      auth.user = _bob;
      controller.handleAuthChange();
      expect(
        (await controller.readRecentRecommendations()).single.details.name,
        'Bob coat',
      );
      await expectLater(
        controller.beginRecentOpen('missing'),
        throwsStateError,
      );
      await controller.clearRecentRecommendations();
      expect(await controller.readRecentRecommendations(), isEmpty);
      expect((await store.read(_alice.id)).single.details.name, 'Alice coat');
      expect(catalog.opens, 0);
    },
  );

  test(
    'an observed auth change rejects a previous session’s pending open',
    () async {
      final authChanges = StreamController<String?>.broadcast();
      addTearDown(authChanges.close);
      final controller = RecommendationController(
        recommendationRepository: catalog,
        authRepository: auth,
        connectivity: connectivity,
        recentRecommendations: store,
        watchAuthUserIds: () => authChanges.stream,
      );
      final pending = Completer<ProductRecommendation>();
      catalog.openResult = pending.future;
      final opened = controller.beginCatalogOpen(_item);
      final switched = controller.historyChanges.first;

      auth.user = _bob;
      authChanges.add(_bob.id);
      await switched;
      expect(controller.isCurrentCatalogOpen(opened), isFalse);
      pending.complete(_recommendation('belongs-to-alice'));
      expect((await opened.recommendation).error, isA<StateError>());
      expect(await store.read(_alice.id), isEmpty);
      expect(await store.read(_bob.id), isEmpty);
    },
  );

  test('a late open after clearing history cannot recreate a visit', () async {
    final controller = createController();
    final pending = Completer<ProductRecommendation>();
    catalog.openResult = pending.future;
    final opened = controller.beginCatalogOpen(_item);
    await controller.clearRecentRecommendations();
    pending.complete(_recommendation('checked-after-clear'));

    expect(
      (await opened.recommendation).value?.recommendationEventId,
      'checked-after-clear',
    );
    expect(await controller.readRecentRecommendations(), isEmpty);
  });

  test(
    'profile and product mutations clear history for the affected UID',
    () async {
      final deps = createTestDependencies(
        authRepositoryOverride: auth,
        recommendationRepository: catalog,
        recentRecommendations: store,
        profiles: const [
          UserProfile(
            id: 'alice',
            name: 'Alice',
            email: 'alice@example.com',
            gender: 'female',
            age: 25,
            preferredCategoryId: 'fashion',
            cityId: 'bogota',
          ),
        ],
      );
      final controller = deps.recommendationController;
      await store.record(_alice.id, _entry('coat', 'Alice coat'));
      await store.record(_bob.id, _entry('coat', 'Bob coat'));
      final pending = Completer<ProductRecommendation>();
      catalog.openResult = pending.future;
      final opened = controller.beginCatalogOpen(_item);

      await deps.profileController.updateCurrentProfile(
        const UserProfileUpdate(
          name: 'Alice',
          gender: 'female',
          age: 26,
          preferredCategoryId: 'fashion',
          cityId: 'bogota',
        ),
      );
      pending.complete(_recommendation('obsolete'));
      expect((await opened.recommendation).error, isA<StateError>());
      expect(await store.read(_alice.id), isEmpty);

      await store.record(_alice.id, _entry('coat', 'Alice coat'));
      await deps.productController.delete('owned-product');
      expect(await store.read(_alice.id), isEmpty);
      expect((await store.read(_bob.id)).single.details.name, 'Bob coat');
    },
  );

  test(
    'local I/O errors leave live recommendation and its event available',
    () async {
      final controller = createController();
      final sqlite = await db.open();
      await sqlite.execute('DROP TABLE recent_recommendations');

      await expectLater(
        controller.readRecentRecommendations(),
        throwsA(isA<DatabaseException>()),
      );
      await expectLater(
        controller.clearRecentRecommendations(),
        throwsA(isA<DatabaseException>()),
      );
      await controller.invalidateAfterHistoryInputsChanged(_alice.id);
      final opened = await controller.beginCatalogOpen(_item).recommendation;
      expect(opened.error, isNull);
      expect(opened.value?.recommendationEventId, 'backend-1');
      expect(controller.isCatalogProductCached('coat'), isTrue);
      // Let the best-effort write reach SQLite before tearing down its owner.
      await sqlite.query('product_drafts');
    },
  );

  testWidgets('the Home history button opens an empty screen', (tester) async {
    connectivity.setStatus(NetworkStatus.offline);
    final deps = createTestDependencies(
      authRepositoryOverride: auth,
      recommendationRepository: catalog,
      recentRecommendations: _WidgetHistory(),
      connectivity: connectivity,
    );

    await tester.pumpWidget(WhyNotApp(dependencies: deps));
    await tester.pumpAndSettle();
    final historyButton = find.widgetWithText(PillButton, 'Recently viewed');
    final explore = find.widgetWithText(PillButton, 'Explore recommendations');
    await tester.ensureVisible(historyButton);
    await tester.pumpAndSettle();
    expect(
      tester.getTopLeft(historyButton).dy,
      greaterThan(tester.getBottomLeft(explore).dy),
    );
    expect(find.text('No recently viewed recommendations yet.'), findsNothing);

    await tester.tap(historyButton);
    await tester.pumpAndSettle();
    expect(find.byType(RecentlyViewedScreen), findsOneWidget);
    expect(
      find.text('No recently viewed recommendations yet.'),
      findsOneWidget,
    );
    expect(find.text('Clear history'), findsNothing);
  });

  testWidgets('offline history is visible and Save waits for a fresh event', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final history = _WidgetHistory();
    await history.record(_alice.id, _entry('coat', 'Stored coat'));
    connectivity.setStatus(NetworkStatus.offline);
    final deps = createTestDependencies(
      authRepositoryOverride: auth,
      recommendationRepository: catalog,
      recentRecommendations: history,
      connectivity: connectivity,
      wishlists: const [
        Wishlist(
          id: 'fashion-list',
          ownerId: 'alice',
          categoryId: 'fashion',
          imageUrl: '',
        ),
      ],
    );

    await tester.pumpWidget(WhyNotApp(dependencies: deps));
    await tester.pumpAndSettle();
    final historyRow = find.byKey(const ValueKey('recent-coat'));
    expect(historyRow, findsNothing);
    await tester.tap(find.widgetWithText(PillButton, 'Recently viewed'));
    await tester.pumpAndSettle();
    await tester.tap(historyRow);
    await tester.pumpAndSettle();
    expect(find.text('Stored coat'), findsOneWidget);
    expect(find.text('Details may be outdated'), findsOneWidget);
    final save = find.widgetWithText(PillButton, 'Save this product');
    expect(tester.widget<PillButton>(save).onPressed, isNull);
    expect(catalog.opens, 0);

    final pending = Completer<ProductRecommendation>();
    catalog.openResult = pending.future;
    connectivity.setStatus(NetworkStatus.available);
    await tester.pumpAndSettle();
    expect(find.text('Checking availability...'), findsOneWidget);
    expect(find.text('Details may be outdated'), findsOneWidget);
    pending.completeError(StateError('Backend unavailable'));
    await tester.pumpAndSettle();
    expect(tester.widget<PillButton>(save).onPressed, isNull);
    expect(catalog.saves, isEmpty);

    catalog.openResult = Future.value(
      _recommendation('new-event', name: 'Checked coat'),
    );
    await tester.tap(find.text('Check availability'));
    await tester.pumpAndSettle();
    expect(find.text('Checked coat'), findsOneWidget);
    expect(find.text('Details may be outdated'), findsNothing);
    expect(tester.widget<PillButton>(save).onPressed, isNotNull);
    await tester.tap(save);
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(ListTile),
      ),
    );
    await tester.pumpAndSettle();
    expect(catalog.saves.single.recommendationEventId, 'new-event');

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Checked coat'), findsOneWidget);
    await tester.tap(find.text('Clear history'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.widgetWithText(TextButton, 'Clear history'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Recently viewed'), findsOneWidget);
    expect(
      find.text('No recently viewed recommendations yet.'),
      findsOneWidget,
    );
    expect(find.text('Clear history'), findsNothing);
    expect(catalog.homeEvents, isEmpty);
  });
}

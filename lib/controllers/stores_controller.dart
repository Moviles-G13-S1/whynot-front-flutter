import 'dart:async';
import 'dart:developer';

import 'package:flutter/foundation.dart';

import '../models/product.dart';
import '../models/repositories/store_summary_store.dart';
import '../models/store_summary.dart';
import 'connectivity_status.dart';

/// Where the visible Stores grouping came from.
enum StoresSource {
  /// Nothing to show yet.
  none,

  /// The last grouping saved on this device (SQLite).
  device,

  /// Grouped from products Firestore served from its offline cache.
  cache,

  /// Grouped from products confirmed by the server.
  live,
}

/// Runs the grouping; production sends it to a background isolate.
typedef StoreGrouper = Future<StoreSummary> Function(StoreGroupingInput input);

Future<StoreSummary> groupOnBackgroundIsolate(StoreGroupingInput input) =>
    compute(groupProductsByStore, input, debugLabel: 'groupProductsByStore');

/// Santiago Casasbuenas: Sprint 4 Stores view.
///
/// - Multithreading: every product snapshot is grouped on a background
///   isolate, so URL parsing and sorting never block the UI thread.
/// - Local storage: the last grouping is saved per account in SQLite and shown
///   immediately on the next visit, before Firestore answers.
/// - Eventual connectivity: offline, the view groups the products Firestore
///   cached; with no cache it falls back to the device copy, and a new server
///   snapshot replaces both once the connection returns. An empty cache is
///   never shown as "no products"; the view waits for the connection.
class StoresController extends ChangeNotifier {
  StoresController({
    required Stream<OwnerProducts> Function() watchProducts,
    required String? Function() currentUserId,
    required this.connectivity,
    StoreSummaryStore? store,
    StoreGrouper grouper = groupOnBackgroundIsolate,
    DateTime Function() now = DateTime.now,
  }) : _watchProducts = watchProducts,
       _currentUserId = currentUserId,
       _store = store,
       _grouper = grouper,
       _now = now {
    connectivity.addListener(_onConnectivityChanged);
  }

  final Stream<OwnerProducts> Function() _watchProducts;
  final String? Function() _currentUserId;
  final ConnectivityStatus connectivity;
  final StoreSummaryStore? _store;
  final StoreGrouper _grouper;
  final DateTime Function() _now;

  StreamSubscription<OwnerProducts>? _subscription;
  int _generation = 0;
  int _groupingTicket = 0;
  bool _disposed = false;
  bool _wasOffline = false;

  StoreSummary? summary;
  StoresSource source = StoresSource.none;
  bool grouping = false;
  bool hasPendingWrites = false;
  Object? error;

  /// When the server last confirmed this account's products, if known.
  DateTime? confirmedAt;

  /// Firestore answered, but only with an empty cache: nothing is known yet.
  bool cacheWasEmpty = false;

  /// The user whose grouping is visible; never shown to another account.
  String? _userId;

  /// The products [summary] was grouped from; null for the device copy.
  List<StoreGroupingKey>? _groupedKey;

  bool get isOffline => connectivity.isOffline;
  bool get isLoading => summary == null && error == null;

  /// Offline with neither cached products nor a device copy to show.
  bool get waitingForConnection => summary == null && isOffline;

  /// The visible grouping may not match the server.
  bool get mayBeOutdated =>
      summary != null && (source != StoresSource.live || isOffline);

  void start() {
    if (_disposed) return;
    final generation = ++_generation;
    unawaited(_subscription?.cancel());
    _subscription = null;
    error = null;
    final userId = _currentUserId();
    if (userId != _userId) {
      summary = null;
      _groupedKey = null;
      source = StoresSource.none;
      confirmedAt = null;
      hasPendingWrites = false;
    }
    cacheWasEmpty = false;
    _userId = userId;
    _wasOffline = isOffline;
    _notify();
    if (userId == null) return;

    unawaited(_readDeviceCopy(generation, userId));
    _subscription = _watchProducts().listen(
      (snapshot) => unawaited(_group(generation, userId, snapshot)),
      onError: (Object failure) {
        if (_disposed || generation != _generation) return;
        error = failure;
        _notify();
      },
    );
  }

  /// Retry after an error or a manual refresh.
  Future<void> retry() async {
    await connectivity.refresh();
    start();
  }

  StoreGroup? groupFor(String domain) {
    for (final group in summary?.groups ?? const <StoreGroup>[]) {
      if (group.domain == domain) return group;
    }
    return null;
  }

  Future<void> _readDeviceCopy(int generation, String userId) async {
    final store = _store;
    if (store == null) return;
    try {
      final saved = await store.read(userId);
      if (_disposed || generation != _generation || saved == null) return;
      if (source == StoresSource.live) return;
      // The copy is the last server-confirmed state, even behind a cache.
      final savedAt = saved.computedAt;
      if (confirmedAt == null || savedAt.isAfter(confirmedAt!)) {
        confirmedAt = savedAt;
      }
      // A cached grouping with products is newer than the copy.
      if (source != StoresSource.cache || summary!.totalProducts == 0) {
        summary = saved;
        _groupedKey = null;
        source = StoresSource.device;
      }
      _notify();
    } catch (_) {
      // The device copy is optional; Firestore still loads the view.
    }
  }

  Future<void> _group(
    int generation,
    String userId,
    OwnerProducts snapshot,
  ) async {
    final products = snapshot.products;
    if (_disposed || generation != _generation) return;
    final ticket = ++_groupingTicket;
    final fromCache = snapshot.fromCache;
    // An empty cache only means Firestore has nothing stored yet. It must not
    // read as "no products": keep the device copy, or wait for the server.
    if (fromCache && products.isEmpty && source != StoresSource.cache) {
      grouping = false;
      cacheWasEmpty = true;
      _notify();
      return;
    }
    final key = storeGroupingKey(products);
    final current = summary;
    final StoreSummary result;
    if (current != null && listEquals(key, _groupedKey)) {
      // Santiago Casasbuenas: Sprint 4 micro-optimization. Firestore sends the
      // same products again when only metadata changes (cache -> server,
      // pending writes confirmed) and after every resubscription. Grouping
      // them again would start an isolate and rebuild every tile for an
      // identical result, so the visible grouping is reused.
      Timeline.instantSync(
        'Stores snapshot reused',
        arguments: {'products': products.length, 'fromCache': fromCache},
      );
      result = fromCache ? current : current.withComputedAt(_now());
    } else {
      grouping = true;
      // Visible in DevTools > Performance (profile builds).
      final task = TimelineTask()
        ..start(
          'Stores grouping',
          arguments: {'products': products.length, 'fromCache': fromCache},
        );
      try {
        result = await _grouper((products: products, computedAt: _now()));
      } catch (failure) {
        if (_disposed || ticket != _groupingTicket) return;
        grouping = false;
        error = failure;
        _notify();
        return;
      } finally {
        task.finish();
      }
      // Only the newest snapshot may replace what is on screen.
      if (_disposed || generation != _generation || ticket != _groupingTicket) {
        return;
      }
    }
    grouping = false;
    _groupedKey = key;
    summary = result;
    source = fromCache ? StoresSource.cache : StoresSource.live;
    hasPendingWrites = snapshot.hasPendingWrites;
    cacheWasEmpty = false;
    if (!fromCache) confirmedAt = result.computedAt;
    error = null;
    _notify();
    // Only server-confirmed groupings are saved as the device copy.
    final store = _store;
    if (store != null && !fromCache) {
      unawaited(store.write(userId, result).catchError((_) {}));
    }
  }

  void _onConnectivityChanged() {
    final offline = isOffline;
    // Back online: subscribe again so the server snapshot replaces the cache.
    if (_wasOffline && !offline && _userId != null) {
      start();
      return;
    }
    _wasOffline = offline;
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    connectivity.removeListener(_onConnectivityChanged);
    unawaited(_subscription?.cancel());
    super.dispose();
  }
}

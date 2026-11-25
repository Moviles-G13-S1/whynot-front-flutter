import 'dart:async';

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
///   snapshot replaces both once the connection returns.
class StoresController extends ChangeNotifier {
  StoresController({
    required Stream<List<Product>> Function() watchProducts,
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

  final Stream<List<Product>> Function() _watchProducts;
  final String? Function() _currentUserId;
  final ConnectivityStatus connectivity;
  final StoreSummaryStore? _store;
  final StoreGrouper _grouper;
  final DateTime Function() _now;

  StreamSubscription<List<Product>>? _subscription;
  int _generation = 0;
  int _groupingTicket = 0;
  bool _disposed = false;
  bool _wasOffline = false;

  StoreSummary? summary;
  StoresSource source = StoresSource.none;
  bool grouping = false;
  bool hasPendingWrites = false;
  Object? error;

  /// The user whose grouping is visible; never shown to another account.
  String? _userId;

  bool get isOffline => connectivity.isOffline;
  bool get isLoading => summary == null && error == null;

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
      source = StoresSource.none;
    }
    _userId = userId;
    _wasOffline = isOffline;
    _notify();
    if (userId == null) return;

    unawaited(_readDeviceCopy(generation, userId));
    _subscription = _watchProducts().listen(
      (products) => unawaited(_group(generation, userId, products)),
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
      // Server data is always newer; so is a cached grouping with products.
      if (source == StoresSource.live) return;
      if (source == StoresSource.cache && summary!.totalProducts > 0) return;
      summary = saved;
      source = StoresSource.device;
      _notify();
    } catch (_) {
      // The device copy is optional; Firestore still loads the view.
    }
  }

  Future<void> _group(
    int generation,
    String userId,
    List<Product> products,
  ) async {
    if (_disposed || generation != _generation) return;
    final ticket = ++_groupingTicket;
    grouping = true;
    _notify();
    final StoreSummary result;
    try {
      result = await _grouper((products: products, computedAt: _now()));
    } catch (failure) {
      if (_disposed || ticket != _groupingTicket) return;
      grouping = false;
      error = failure;
      _notify();
      return;
    }
    // Only the newest snapshot may replace what is on screen.
    if (_disposed || generation != _generation || ticket != _groupingTicket) {
      return;
    }
    // An empty list carries no cache flag; offline it is treated as cached.
    final fromCache = products.isEmpty
        ? isOffline
        : products.any((item) => item.fromCache);
    // An empty cached result says nothing; keep the device copy instead.
    if (fromCache && products.isEmpty && source == StoresSource.device) {
      grouping = false;
      _notify();
      return;
    }
    summary = result;
    source = fromCache ? StoresSource.cache : StoresSource.live;
    hasPendingWrites = products.any((item) => item.hasPendingWrites);
    grouping = false;
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

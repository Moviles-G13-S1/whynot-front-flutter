import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/monthly_spending.dart';
import '../models/product.dart';
import '../models/repositories/spending_store.dart';
import 'connectivity_status.dart';
import 'monthly_spending_cache.dart';

/// Owned by Monthly Spending; its category route shares this same snapshot.
class MonthlySpendingController extends ChangeNotifier {
  MonthlySpendingController({
    required this.ownerId,
    required this.currentUserId,
    required this.watchProducts,
    required this.connectivity,
    this.store,
    MonthlySpendingCache? cache,
    DateTime Function()? now,
  }) : cache = cache ?? MonthlySpendingCache(),
       _now = now ?? DateTime.now {
    selectedMonth = spendingMonth(_now());
    connectivity.addListener(_connectionChanged);
  }
  final String ownerId;
  final String? Function() currentUserId;
  final Stream<OwnerProducts> Function() watchProducts;
  final ConnectivityStatus connectivity;
  final SpendingStore? store;
  final MonthlySpendingCache cache;
  final DateTime Function() _now;
  StreamSubscription<void>? _subscription;
  Timer? _waitingTimer;
  SpendingSnapshot? _snapshot;
  MonthlySpending? _summary;
  bool _disposed = false;
  int _generation = 0;
  int _selection = 0;
  bool loading = true;
  bool calculating = false;
  bool stale = true;
  bool pendingWrites = false;
  bool failed = false;
  bool storageFailed = false;
  late String selectedMonth;

  bool get _active => !_disposed && currentUserId() == ownerId;
  bool get hasData => _active && _snapshot != null;
  MonthlySpending? get summary => _active ? _summary : null;
  DateTime? get syncedAt => hasData ? _snapshot?.syncedAt : null;
  int get undatedCount => hasData
      ? _snapshot!.purchases.where((p) => p.purchasedAt == null).length
      : 0;
  bool get offline => connectivity.isOffline;
  List<String> get months {
    final current = spendingDate(_now());
    final values = <String>{selectedMonth};
    for (var i = 0; i < 12; i++) {
      final date = DateTime.utc(current.year, current.month - i);
      values.add('${date.year}-${date.month.toString().padLeft(2, '0')}');
    }
    if (hasData) {
      for (final p in _snapshot!.purchases) {
        if (p.purchasedAt != null) values.add(spendingMonth(p.purchasedAt!));
      }
    }
    return values.toList()..sort((a, b) => b.compareTo(a));
  }

  Future<void> start() async {
    if (!_active) {
      loading = false;
      return;
    }
    final generation = ++_generation;
    try {
      final saved = await store?.load(ownerId);
      if (!_valid(generation)) return;
      if (saved != null) {
        _snapshot = saved;
        cache.invalidate();
        await selectMonth(selectedMonth);
      }
    } catch (_) {
      if (_valid(generation)) storageFailed = true;
    }
    if (!_valid(generation)) return;
    _subscribe(generation);
  }

  bool _valid(int generation) => _active && generation == _generation;
  void _notify() {
    if (!_disposed) notifyListeners();
  }

  void _subscribe(int generation) {
    _waitingTimer?.cancel();
    if (!hasData) {
      loading = !offline;
      _waitingTimer = Timer(const Duration(seconds: 12), () {
        if (_valid(generation) && !hasData) {
          loading = false;
          failed = true;
          _notify();
        }
      });
    }
    // asyncMap serializes persistence and worker updates from this subscription.
    _subscription = watchProducts()
        .asyncMap((event) => _receive(event, generation))
        .listen(
          (_) {},
          onError: (Object error, StackTrace stack) {
            if (!_valid(generation)) return;
            _waitingTimer?.cancel();
            loading = false;
            stale = true;
            failed = true;
            _notify();
          },
        );
    _notify();
  }

  Future<void> _receive(OwnerProducts event, int generation) async {
    if (!_valid(generation)) return;
    // A partial Firestore cache must not replace a complete SQLite snapshot.
    if (event.fromCache || event.hasPendingWrites) {
      stale = true;
      pendingWrites = event.hasPendingWrites;
      if (!hasData && offline) loading = false;
      _notify();
      return;
    }
    final purchases = <SpendingPurchase>[];
    for (final product in event.products) {
      if (product.ownerId != ownerId) continue;
      final purchase = SpendingPurchase.fromProduct(product);
      if (purchase != null) purchases.add(purchase);
    }
    final snapshot = SpendingSnapshot(
      purchases: purchases,
      syncedAt: _now().toUtc(),
    );
    _snapshot = snapshot;
    stale = false;
    pendingWrites = false;
    failed = false;
    loading = false;
    _waitingTimer?.cancel();
    cache.invalidate();
    await selectMonth(selectedMonth);
    if (!_valid(generation)) return;
    try {
      await store?.save(ownerId, snapshot);
      if (_valid(generation)) storageFailed = false;
    } catch (_) {
      if (_valid(generation)) storageFailed = true;
    }
    _notify();
  }

  Future<void> selectMonth(String month) async {
    if (!_active || !RegExp(r'^\d{4}-(0[1-9]|1[0-2])$').hasMatch(month)) return;
    selectedMonth = month;
    final snapshot = _snapshot;
    if (snapshot == null) return;
    final selection = ++_selection;
    calculating = true;
    _summary = null;
    _notify();
    try {
      final result = await cache.resolve(month, snapshot.purchases);
      if (!_active || selection != _selection) return;
      _summary = result;
    } catch (_) {
      if (_active && selection == _selection) failed = true;
    } finally {
      if (_active && selection == _selection) {
        calculating = false;
        loading = false;
        _notify();
      }
    }
  }

  Future<void> refresh() async {
    if (!_active || offline) return;
    final generation = ++_generation;
    await _subscription?.cancel();
    if (!_valid(generation)) return;
    failed = false;
    stale = true;
    _subscribe(generation);
  }

  void _connectionChanged() {
    if (!_active) return;
    if (offline) {
      stale = true;
      loading = false;
      _notify();
    } else {
      unawaited(refresh());
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    _selection++;
    _waitingTimer?.cancel();
    connectivity.removeListener(_connectionChanged);
    unawaited(_subscription?.cancel());
    cache.invalidate();
    _snapshot = null;
    _summary = null;
    super.dispose();
  }
}

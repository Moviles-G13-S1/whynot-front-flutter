import 'package:flutter/foundation.dart';
import '../models/monthly_spending.dart';

typedef SpendingRequest = ({String month, List<SpendingPurchase> purchases});

/// Pure worker; no database handles, Firebase objects or widgets cross isolates.
MonthlySpending calculateMonthlySpending(SpendingRequest request) {
  final groups = <String, List<SpendingPurchase>>{};
  for (final p in request.purchases) {
    if (p.purchasedAt == null ||
        spendingMonth(p.purchasedAt!) != request.month) {
      continue;
    }
    (groups[p.categoryId] ??= []).add(p);
  }
  final categories =
      groups.entries.map((entry) {
        entry.value.sort((a, b) {
          final date = b.purchasedAt!.compareTo(a.purchasedAt!);
          return date != 0 ? date : a.id.compareTo(b.id);
        });
        return SpendingCategory(entry.key, entry.value);
      }).toList()..sort((a, b) {
        final total = b.totalCents.compareTo(a.totalCents);
        return total != 0 ? total : a.id.compareTo(b.id);
      });
  return MonthlySpending(request.month, categories);
}

Future<MonthlySpending> _runWorker(SpendingRequest request) => compute(
  calculateMonthlySpending,
  request,
  debugLabel: 'monthly_spending_worker',
);

/// LRU: accessing a month moves it to the end; the oldest access is evicted.
class MonthlySpendingCache {
  MonthlySpendingCache({
    this.capacity = 6,
    Future<MonthlySpending> Function(SpendingRequest)? worker,
  }) : assert(capacity > 0),
       _worker = worker ?? _runWorker;
  final int capacity;
  final Future<MonthlySpending> Function(SpendingRequest) _worker;
  final _entries = <String, MonthlySpending>{};
  final _pending = <String, Future<MonthlySpending>>{};
  int _generation = 0;
  int hits = 0;
  int misses = 0;

  void invalidate() {
    _generation++;
    _entries.clear();
    _pending.clear();
  }

  Future<MonthlySpending> resolve(
    String month,
    List<SpendingPurchase> purchases,
  ) {
    final hit = _entries.remove(month);
    if (hit != null) {
      hits++;
      _entries[month] = hit;
      return Future.value(hit);
    }
    final pending = _pending[month];
    if (pending != null) return pending;
    misses++;
    final generation = _generation;
    final future = _worker((month: month, purchases: purchases)).then(
      (result) {
        if (generation == _generation) {
          _pending.remove(month);
          if (_entries.length >= capacity) _entries.remove(_entries.keys.first);
          _entries[month] = result;
        }
        return result;
      },
      onError: (Object error, StackTrace stack) {
        if (generation == _generation) _pending.remove(month);
        Error.throwWithStackTrace(error, stack);
      },
    );
    _pending[month] = future;
    return future;
  }
}

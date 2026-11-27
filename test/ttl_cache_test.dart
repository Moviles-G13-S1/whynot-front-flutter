import 'package:flutter_test/flutter_test.dart';
import 'package:whynot_mobile/infrastructure/cache/ttl_cache.dart';

void main() {
  late Duration elapsed;
  late TtlCache<List<String>> cache;

  setUp(() {
    elapsed = Duration.zero;
    cache = TtlCache<List<String>>(
      ttl: const Duration(minutes: 20),
      elapsed: () => elapsed,
    );
  });

  test('empty cache is a miss', () {
    expect(cache.read(), isNull);
  });

  test('returns the cached value before the TTL expires', () {
    cache.write(['Technology', 'Beauty']);
    elapsed = const Duration(minutes: 19, seconds: 59);
    expect(cache.read(), ['Technology', 'Beauty']);
  });

  test('expires at exactly 20 minutes; reads do not renew TTL', () {
    cache.write(['Technology']);
    elapsed = const Duration(minutes: 10);
    expect(cache.read(), ['Technology']);
    elapsed = const Duration(minutes: 20);
    expect(cache.read(), isNull);
    expect(cache.read(), isNull);
  });

  test('writing a fresh value restarts its TTL', () {
    cache.write(['Technology']);
    elapsed = const Duration(minutes: 15);
    cache.write(['Beauty']);
    elapsed = const Duration(minutes: 34, seconds: 59);
    expect(cache.read(), ['Beauty']);
    elapsed = const Duration(minutes: 35);
    expect(cache.read(), isNull);
  });

  test('manual invalidation removes the cached value', () {
    cache.write(['Technology']);
    cache.invalidate();
    expect(cache.read(), isNull);
  });

  test('an empty catalog is a valid cached value', () {
    cache.write([]);
    expect(cache.read(), isEmpty);
  });
}

/// A single-value, in-memory cache with a fixed expiration time.
/// Reading an entry never extends its lifetime.
class TtlCache<T extends Object> {
  TtlCache({required this.ttl, Duration Function()? elapsed})
    : assert(ttl > Duration.zero),
      _elapsed = elapsed ?? _monotonicClock();

  final Duration ttl;
  final Duration Function() _elapsed;
  T? _value;
  Duration? _writtenAt;

  static Duration Function() _monotonicClock() {
    final stopwatch = Stopwatch()..start();
    return () => stopwatch.elapsed;
  }

  T? read() {
    final writtenAt = _writtenAt;
    if (writtenAt == null) return null;
    if (_elapsed() - writtenAt >= ttl) {
      invalidate();
      return null;
    }
    return _value;
  }

  void write(T value) {
    _value = value;
    _writtenAt = _elapsed();
  }

  void invalidate() {
    _value = null;
    _writtenAt = null;
  }
}

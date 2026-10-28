import 'dart:async';

import 'package:flutter/widgets.dart';

/// One independently retryable subscription owned by a screen's controller.
/// Starting a section never waits for another section to finish loading.
class LiveSection<T> extends ChangeNotifier {
  LiveSection(this._source);

  final Stream<T> Function() _source;
  StreamSubscription<T>? _subscription;
  AsyncSnapshot<T> snapshot = AsyncSnapshot<T>.nothing();
  int _generation = 0;
  bool _disposed = false;
  bool hasValue = false;
  T? _lastValue;

  /// Keep the most recent data visible during failed reads and retries.
  /// Owned by this screen; no data is shared between accounts.
  AsyncSnapshot<T> get visibleSnapshot => hasValue
      ? AsyncSnapshot<T>.withData(ConnectionState.active, _lastValue as T)
      : snapshot;

  void start() {
    if (_disposed) return;
    final generation = ++_generation;
    final previous = _subscription;
    _subscription = null;
    snapshot = AsyncSnapshot<T>.waiting();
    notifyListeners();
    unawaited(_subscribe(generation, previous));
  }

  Future<void> _subscribe(
    int generation,
    StreamSubscription<T>? previous,
  ) async {
    await previous?.cancel();
    if (_disposed || generation != _generation) return;
    try {
      _subscription = _source().listen(
        (data) {
          if (_disposed || generation != _generation) return;
          hasValue = true;
          _lastValue = data;
          snapshot = AsyncSnapshot.withData(ConnectionState.active, data);
          notifyListeners();
        },
        onError: (Object error, StackTrace stack) {
          if (_disposed || generation != _generation) return;
          snapshot = AsyncSnapshot.withError(
            ConnectionState.active,
            error,
            stack,
          );
          notifyListeners();
        },
        onDone: () {
          if (_disposed || generation != _generation) return;
          snapshot = snapshot.inState(ConnectionState.done);
          notifyListeners();
        },
      );
    } catch (error, stack) {
      if (_disposed || generation != _generation) return;
      snapshot = AsyncSnapshot.withError(ConnectionState.active, error, stack);
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    unawaited(_subscription?.cancel());
    super.dispose();
  }
}

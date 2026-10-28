import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/widgets.dart';

/// A transport signal. A non-none transport does not prove backend reachability.
enum NetworkStatus { unknown, offline, available }

class ConnectivityStatus extends ChangeNotifier with WidgetsBindingObserver {
  ConnectivityStatus({Connectivity? connectivity, bool observe = true})
    : _connectivity = connectivity ?? Connectivity() {
    if (observe) {
      WidgetsBinding.instance.addObserver(this);
      _subscription = _connectivity.onConnectivityChanged.listen(_update);
      refresh();
    }
  }

  final Connectivity _connectivity;
  StreamSubscription<List<ConnectivityResult>>? _subscription;
  NetworkStatus _status = NetworkStatus.unknown;
  int _backendConfirmationVersion = 0;
  NetworkStatus get status => _status;
  bool get isOffline => _status == NetworkStatus.offline;

  /// Recheck a possibly stale offline signal before a user-initiated action.
  /// Available transport is permission to try, not proof of backend access.
  Future<bool> canAttemptNetwork() async {
    if (isOffline) await refresh();
    return !isOffline;
  }

  /// Recheck the device transport when the app becomes active again.
  Future<void> refresh() async {
    final version = _backendConfirmationVersion;
    try {
      final results = await _connectivity.checkConnectivity();
      if (version == _backendConfirmationVersion) _update(results);
    } catch (_) {
      // Keep the last known status; an explicit read can still verify access.
    }
  }

  /// A successful backend read is stronger evidence than a stale OS signal.
  void confirmReachable() {
    _backendConfirmationVersion++;
    setStatus(NetworkStatus.available);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) refresh();
  }

  @visibleForTesting
  void setStatus(NetworkStatus status) {
    if (_status == status) return;
    _status = status;
    notifyListeners();
  }

  void _update(List<ConnectivityResult> results) => setStatus(
    results.isEmpty ||
            results.every((result) => result == ConnectivityResult.none)
        ? NetworkStatus.offline
        : NetworkStatus.available,
  );

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _subscription?.cancel();
    super.dispose();
  }
}

import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

/// A transport signal. A non-none transport does not prove backend reachability.
enum NetworkStatus { unknown, offline, available }

class ConnectivityStatus extends ChangeNotifier {
  ConnectivityStatus({Connectivity? connectivity, bool observe = true})
    : _connectivity = connectivity ?? Connectivity() {
    if (observe) {
      _subscription = _connectivity.onConnectivityChanged.listen(_update);
      _connectivity.checkConnectivity().then(_update).catchError((Object _) {});
    }
  }

  final Connectivity _connectivity;
  StreamSubscription<List<ConnectivityResult>>? _subscription;
  NetworkStatus _status = NetworkStatus.unknown;
  NetworkStatus get status => _status;
  bool get isOffline => _status == NetworkStatus.offline;

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
    _subscription?.cancel();
    super.dispose();
  }
}

import 'connectivity_status.dart';

/// Retries failed reads after transport recovers. A transport change alone
/// never confirms a backend write or automatically resubmits a form.
class ConnectionRecovery {
  ConnectionRecovery(this.connectivity, this.onRecovered)
    : _previous = connectivity?.status {
    connectivity?.addListener(_changed);
  }

  final ConnectivityStatus? connectivity;
  final void Function() onRecovered;
  NetworkStatus? _previous;

  void _changed() {
    final status = connectivity?.status;
    final recovered =
        _previous == NetworkStatus.offline && status == NetworkStatus.available;
    _previous = status;
    if (recovered) onRecovered();
  }

  void dispose() => connectivity?.removeListener(_changed);
}

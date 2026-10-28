class NetworkFailure implements Exception {
  const NetworkFailure();
  String get message =>
      'You are offline. Your inputs are still here. Reconnect and try again.';
}

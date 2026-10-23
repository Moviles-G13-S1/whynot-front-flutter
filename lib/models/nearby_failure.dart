enum NearbyFailureKind {
  permissionDenied,
  permissionPermanentlyDenied,
  servicesDisabled,
  locationUnavailable,
  nearbyServiceUnavailable,
}

/// Identifies the failed stage without exposing platform or backend details.
class NearbyFailure implements Exception {
  const NearbyFailure(this.kind);

  final NearbyFailureKind kind;
}

/// Domain model representing the store selected by the Context-Aware backend.
///
/// The backend returns at most one store: preferably the nearest store
/// associated with the user's preferred category. If no store matches that
/// category, it returns the nearest store overall.
class NearbyStore {
  const NearbyStore({
    required this.id,
    required this.name,
    required this.address,
    required this.latitude,
    required this.longitude,
    required this.categoryIds,
    required this.websiteUrl,
    required this.imageUrl,
    required this.distanceKm,
  });

  /// Firestore identifier of the store.
  final String id;

  /// Store name displayed to the user.
  final String name;

  /// Human-readable store address.
  final String address;

  /// Store latitude in decimal degrees.
  final double latitude;

  /// Store longitude in decimal degrees.
  final double longitude;

  /// Categories associated with this store.
  final List<String> categoryIds;

  /// Store website returned by the backend.
  final String websiteUrl;

  /// Optional image URL used by the presentation layer.
  final String imageUrl;

  /// Distance between the user's current location and the store,
  /// expressed in kilometers.
  final double distanceKm;
}
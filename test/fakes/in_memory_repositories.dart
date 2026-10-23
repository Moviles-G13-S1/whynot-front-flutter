import 'package:whynot_mobile/models/repositories/auth_repository.dart';
import 'package:whynot_mobile/models/auth_user.dart';
import 'package:whynot_mobile/models/product.dart';
import 'package:whynot_mobile/models/repositories/product_repository.dart';
import 'package:whynot_mobile/models/user_profile.dart';
import 'package:whynot_mobile/models/repositories/user_repository.dart';
import 'package:whynot_mobile/models/wishlist.dart';
import 'package:whynot_mobile/models/repositories/wishlist_repository.dart';
import 'package:whynot_mobile/models/category.dart';
import 'package:whynot_mobile/models/city.dart';
import 'package:whynot_mobile/models/repositories/city_repository.dart';

class InMemoryCityRepository implements CityRepository {
  InMemoryCityRepository({
    this.cities = const [
      City(id: 'bogota', name: 'Bogotá'),
      City(id: 'medellin', name: 'Medellín'),
      City(id: 'other', name: 'Other'),
    ],
  });

  final List<City> cities;

  @override
  Future<List<City>> getCities() async => cities;
}

class InMemoryAuthRepository implements AuthRepository {
  InMemoryAuthRepository({this.user, this.claims = const {}});

  AuthUser? user;
  Map<Object?, Object?> claims;

  @override
  AuthUser? get currentUser => user;

  @override
  Future<AuthUser> signIn({
    required String email,
    required String password,
  }) async {
    user = AuthUser(id: 'test-user', email: email);
    return user!;
  }

  @override
  Future<AuthUser> createUser({
    required String email,
    required String password,
  }) => signIn(email: email, password: password);

  @override
  Future<void> deleteCurrentUser() async => user = null;

  @override
  Future<void> signOut() async => user = null;

  @override
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {}

  @override
  Future<Map<Object?, Object?>> refreshedClaims() async => claims;
}

class InMemoryUserRepository implements UserRepository {
  InMemoryUserRepository({this.failOnCreate = false});

  final bool failOnCreate;
  final profiles = <String, UserProfile>{};

  @override
  Stream<List<UserProfile>> watchAll() =>
      Stream.value(profiles.values.toList());

  @override
  Stream<UserProfile?> watch(String userId) => Stream.value(profiles[userId]);

  @override
  Future<UserProfile?> get(String userId) async => profiles[userId];

  @override
  Future<void> create(UserProfile profile) async {
    if (failOnCreate) throw StateError('Profile creation failed.');
    profiles[profile.id] = profile;
  }

  @override
  Future<void> update(String userId, UserProfileUpdate update) async {
    final profile = profiles[userId];
    if (profile == null) throw StateError('Profile not found.');
    profiles[userId] = UserProfile(
      id: profile.id,
      name: update.name,
      email: profile.email,
      gender: update.gender,
      age: update.age,
      preferredCategoryId: update.preferredCategoryId,
      cityId: update.cityId,
      photoPath: profile.photoPath,
      createdAt: profile.createdAt,
      updatedAt: DateTime.now(),
    );
  }

  @override
  // Santiago Casasbuenas: Save photo paths in the test profile store.
  Future<void> updatePhotoPath(String userId, String path) async {
    final profile = profiles[userId];
    if (profile == null) throw StateError('Profile not found.');
    profiles[userId] = UserProfile(
      id: profile.id,
      name: profile.name,
      email: profile.email,
      gender: profile.gender,
      age: profile.age,
      preferredCategoryId: profile.preferredCategoryId,
      cityId: profile.cityId,
      photoPath: path,
      createdAt: profile.createdAt,
      updatedAt: DateTime.now(),
    );
  }
}

class InMemoryWishlistRepository implements WishlistRepository {
  InMemoryWishlistRepository({
    this.categories = const [],
    List<Wishlist> wishlists = const [],
  }) : _wishlists = [...wishlists];

  final List<Category> categories;
  final List<Wishlist> _wishlists;
  final interactions =
      <({String action, String outcome, String reason, String? wishlistId})>[];
  final productCounts = <String, int>{};

  @override
  Stream<List<Wishlist>> watchByOwner(String ownerId) => Stream.value(
    _wishlists.where((wishlist) => wishlist.ownerId == ownerId).toList(),
  );

  @override
  Future<List<Wishlist>> getByOwner(String ownerId) async =>
      _wishlists.where((wishlist) => wishlist.ownerId == ownerId).toList();

  @override
  Future<List<Category>> getCategories() async => categories;

  @override
  Future<String> create({
    required String ownerId,
    required String categoryId,
    required String imageUrl,
    String? emoji,
  }) async {
    final id = 'wishlist-${_wishlists.length + 1}';
    _wishlists.add(
      Wishlist(
        id: id,
        ownerId: ownerId,
        categoryId: categoryId,
        imageUrl: imageUrl,
        emoji: emoji,
      ),
    );
    await trackInteraction(
      ownerId: ownerId,
      action: 'create',
      outcome: 'success',
      reason: 'none',
      wishlistId: id,
      categoryId: categoryId,
    );
    return id;
  }

  @override
  Future<void> updatePresentation({
    required String ownerId,
    required String wishlistId,
    required String imageUrl,
    String? emoji,
  }) async {
    final index = _wishlists.indexWhere(
      (wishlist) => wishlist.id == wishlistId && wishlist.ownerId == ownerId,
    );
    if (index < 0) throw StateError('Wishlist not found.');
    final old = _wishlists[index];
    _wishlists[index] = Wishlist(
      id: old.id,
      ownerId: old.ownerId,
      categoryId: old.categoryId,
      imageUrl: imageUrl,
      emoji: emoji,
      createdAt: old.createdAt,
      updatedAt: DateTime.now(),
    );
    await trackInteraction(
      ownerId: ownerId,
      action: 'edit',
      outcome: 'success',
      reason: 'none',
      wishlistId: wishlistId,
    );
  }

  @override
  Future<({String outcome, String reason})> deleteEmpty({
    required String ownerId,
    required String wishlistId,
  }) async {
    final index = _wishlists.indexWhere(
      (wishlist) => wishlist.id == wishlistId && wishlist.ownerId == ownerId,
    );
    final outcome = index < 0
        ? 'failure'
        : (productCounts[wishlistId] ?? 0) > 0
        ? 'blocked'
        : 'success';
    final reason = index < 0
        ? 'not_found'
        : outcome == 'blocked'
        ? 'nonempty'
        : 'none';
    if (outcome == 'success') _wishlists.removeAt(index);
    await trackInteraction(
      ownerId: ownerId,
      action: 'delete',
      outcome: outcome,
      reason: reason,
      wishlistId: wishlistId,
    );
    return (outcome: outcome, reason: reason);
  }

  @override
  Future<void> trackInteraction({
    required String ownerId,
    required String action,
    required String outcome,
    required String reason,
    String? wishlistId,
    String? categoryId,
  }) async {
    interactions.add((
      action: action,
      outcome: outcome,
      reason: reason,
      wishlistId: wishlistId,
    ));
  }
}

class InMemoryProductRepository implements ProductRepository {
  InMemoryProductRepository({List<Product> products = const []})
    : _products = [...products];

  final List<Product> _products;

  /// Save attempts recorded during tests.
  final saveAttempts = <({String ownerId, bool success})>[];

  @override
  Stream<List<Product>> watchAll() => Stream.value(List.of(_products));

  @override
  Stream<List<Product>> watchByWishlist(String wishlistId) => Stream.value(
    _products.where((product) => product.wishlistId == wishlistId).toList(),
  );

  @override
  Stream<List<Product>> watchByOwner(String ownerId) => Stream.value(
    _products.where((product) => product.ownerId == ownerId).toList(),
  );

  @override
  Stream<Product?> watch(String productId) => Stream.value(
    _products.where((product) => product.id == productId).firstOrNull,
  );

  @override
  Future<Product?> get(String productId) async =>
      _products.where((product) => product.id == productId).firstOrNull;

  @override
  Future<void> create({
    required String ownerId,
    required ProductDraft draft,
  }) async {
    _products.add(
      _fromDraft('product-${_products.length + 1}', ownerId, draft),
    );
  }

  /// Simulates the BQ Type 2 analytics event without Firebase.
  @override
  Future<void> recordSaveAttempt({
    required String ownerId,
    required bool success,
  }) async {
    saveAttempts.add((ownerId: ownerId, success: success));
  }

  @override
  Future<void> update(String productId, ProductDraft draft) async {
    final index = _products.indexWhere((product) => product.id == productId);
    final product = _products[index];
    _products[index] = _fromDraft(
      productId,
      product.ownerId,
      draft,
      purchased: product.purchased,
      purchasedAt: product.purchasedAt,
    );
  }

  @override
  Future<void> markPurchased(String productId) async {
    final index = _products.indexWhere((product) => product.id == productId);
    final product = _products[index];
    _products[index] = Product(
      id: product.id,
      ownerId: product.ownerId,
      wishlistId: product.wishlistId,
      categoryId: product.categoryId,
      name: product.name,
      brand: product.brand,
      price: product.price,
      imageUrl: product.imageUrl,
      productUrl: product.productUrl,
      purchased: true,
      purchasedAt: product.purchasedAt ?? DateTime.now(),
      createdAt: product.createdAt,
      updatedAt: DateTime.now(),
    );
  }

  @override
  Future<void> delete(String productId) async {
    _products.removeWhere((product) => product.id == productId);
  }

  Product _fromDraft(
    String id,
    String ownerId,
    ProductDraft draft, {
    bool purchased = false,
    DateTime? purchasedAt,
  }) => Product(
    id: id,
    ownerId: ownerId,
    wishlistId: draft.wishlistId,
    categoryId: draft.categoryId,
    name: draft.name,
    brand: draft.brand,
    price: draft.price,
    imageUrl: draft.imageUrl,
    productUrl: draft.productUrl,
    purchased: purchased,
    purchasedAt: purchasedAt,
  );
}

extension<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}

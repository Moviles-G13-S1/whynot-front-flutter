/// Route names used by the application.
///
/// Keeping them in one place prevents string duplication without introducing a
/// routing package while the navigation flow is still small.
abstract final class AppRoutes {
  static const login = '/login';
  static const createAccount = '/create-account';

  static const home = '/home';

  static const wishlists = '/wishlists';
  static const wishlistDetail = '/wishlist-detail';
  static const newWishlist = '/new-wishlist';

  static const productDetail = '/product-detail';
  static const newProduct = '/new-product';
  static const newProductManual = '/new-product-manual';
  static const editProduct = '/edit-product';

  static const purchases = '/purchases';

  static const profile = '/profile';
  static const editProfile = '/edit-profile';
  static const changePassword = '/change-password';

}
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../features/admin/presentation/demographic_profile_screen.dart';
import '../features/admin/presentation/purchased_products_screen.dart';
import '../features/admin/presentation/save_methods_screen.dart';
import '../features/admin/presentation/saved_products_screen.dart';

import '../features/authentication/presentation/create_account_screen.dart';
import '../features/authentication/presentation/login_screen.dart';

import '../features/home/presentation/home_screen.dart';

import '../features/profile/presentation/change_password_screen.dart';
import '../features/profile/presentation/edit_profile_screen.dart';
import '../features/profile/presentation/profile_screen.dart';

import '../features/wishlists/presentation/wishlists_screen.dart';
import '../features/wishlists/presentation/wishlist_detail_screen.dart';
import '../features/wishlists/presentation/new_wishlist_screen.dart';

import '../features/products/presentation/product_detail_screen.dart';
import '../features/products/presentation/new_product_manual_screen.dart';
import '../features/products/presentation/edit_product_screen.dart';

import '../features/purchases/presentation/purchases_screen.dart';

import 'app_routes.dart';
import 'whynot_theme.dart';

/// Root widget that owns global theme and navigation configuration.
class WhyNotApp extends StatelessWidget {
  const WhyNotApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'WhyNot',
      debugShowCheckedModeBanner: false,
      theme: WhyNotTheme.data,

      builder: (context, child) => _WebPreviewFrame(
        child: child ?? const SizedBox.shrink(),
      ),

      initialRoute: _initialRoute,
      onGenerateRoute: _generateRoute,

      routes: {
        // Authentication
        AppRoutes.login: (_) => const LoginScreen(),
        AppRoutes.createAccount: (_) => const CreateAccountScreen(),

        // Home
        AppRoutes.home: (_) => const HomeScreen(),

        // Wishlists
        AppRoutes.wishlists: (_) => const WishlistsScreen(),
        AppRoutes.wishlistDetail: (_) => const WishlistDetailScreen(),
        AppRoutes.newWishlist: (_) => const NewWishlistScreen(),

        // Products
        AppRoutes.productDetail: (_) => const ProductDetailScreen(),

        // Old newProduct route also opens the manual form.
        // This keeps any older navigation calls working.
        AppRoutes.newProduct: (_) => const NewProductManualScreen(),

        // Main route used by the Add button.
        AppRoutes.newProductManual: (_) =>
            const NewProductManualScreen(),

        AppRoutes.editProduct: (_) => const EditProductScreen(),

        // Purchases
        AppRoutes.purchases: (_) => const PurchasesScreen(),

        // Profile
        AppRoutes.profile: (_) => const ProfileScreen(),
        AppRoutes.editProfile: (_) => const EditProfileScreen(),
        AppRoutes.changePassword: (_) =>
            const ChangePasswordScreen(),
      },
    );
  }

  Route<dynamic>? _generateRoute(RouteSettings settings) {
    final screen = switch (settings.name) {
      AppRoutes.adminSavedProducts =>
        const SavedProductsScreen(),

      AppRoutes.adminSaveMethods =>
        const SaveMethodsScreen(),

      AppRoutes.adminPurchasedProducts =>
        const PurchasedProductsScreen(),

      AppRoutes.adminDemographicProfile =>
        const DemographicProfileScreen(),

      _ => null,
    };

    if (screen == null) {
      return null;
    }

    return PageRouteBuilder<void>(
      settings: settings,
      transitionDuration:
          const Duration(milliseconds: 220),
      reverseTransitionDuration:
          const Duration(milliseconds: 180),
      pageBuilder: (
        context,
        animation,
        secondaryAnimation,
      ) =>
          screen,
      transitionsBuilder: (
        context,
        animation,
        secondaryAnimation,
        child,
      ) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );

        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0.08, 0),
            end: Offset.zero,
          ).animate(curved),
          child: FadeTransition(
            opacity: Tween<double>(
              begin: 0,
              end: 1,
            ).animate(curved),
            child: child,
          ),
        );
      },
    );
  }

  /// Allows opening one screen directly during browser-based visual reviews.
  String get _initialRoute {
    if (!kIsWeb) {
      return AppRoutes.login;
    }

    return switch (
        Uri.base.queryParameters['screen']) {
      'create-account' =>
        AppRoutes.createAccount,

      'admin-dashboard' =>
        AppRoutes.adminDashboard,

      'admin-saved-products' =>
        AppRoutes.adminSavedProducts,

      'admin-save-methods' =>
        AppRoutes.adminSaveMethods,

      'admin-purchased-products' =>
        AppRoutes.adminPurchasedProducts,

      'admin-demographic-profile' =>
        AppRoutes.adminDemographicProfile,

      'home' =>
        AppRoutes.home,

      'wishlists' =>
        AppRoutes.wishlists,

      'new-wishlist' =>
        AppRoutes.newWishlist,

      'purchases' =>
        AppRoutes.purchases,

      'profile' =>
        AppRoutes.profile,

      'edit-profile' =>
        AppRoutes.editProfile,

      'change-password' =>
        AppRoutes.changePassword,

      'wishlist-detail' =>
        AppRoutes.wishlistDetail,

      'product-detail' =>
        AppRoutes.productDetail,

      // Both browser preview URLs now open
      // the manual product creation screen.
      'new-product' =>
        AppRoutes.newProductManual,

      'new-product-manual' =>
        AppRoutes.newProductManual,

      'edit-product' =>
        AppRoutes.editProduct,

      _ =>
        AppRoutes.login,
    };
  }
}

/// Displays the web build inside the iPhone-sized canvas used for reviews.
///
/// On iOS this widget is transparent and therefore does not alter native
/// sizing or safe areas.
class _WebPreviewFrame extends StatelessWidget {
  const _WebPreviewFrame({
    required this.child,
  });

  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!kIsWeb) {
      return child;
    }

    return Scaffold(
      backgroundColor: const Color(
        0xFF151515,
      ),
      body: LayoutBuilder(
        builder: (
          context,
          constraints,
        ) =>
            Center(
          child: ClipRRect(
            borderRadius:
                BorderRadius.circular(50),
            child: SizedBox(
              width: constraints.constrainWidth(
                402,
              ),
              height: constraints.constrainHeight(
                874,
              ),
              child: MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(
                  padding:
                      const EdgeInsets.only(
                    top: 47,
                  ),
                ),
                child: child,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../features/authentication/presentation/create_account_screen.dart';
import '../features/authentication/presentation/login_screen.dart';
import '../features/home/presentation/home_screen.dart';
import '../features/profile/presentation/change_password_screen.dart';
import '../features/profile/presentation/edit_profile_screen.dart';
import '../features/profile/presentation/profile_screen.dart';
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
      builder: (context, child) =>
          _WebPreviewFrame(child: child ?? const SizedBox.shrink()),
      initialRoute: _initialRoute,
      routes: {
        AppRoutes.login: (_) => const LoginScreen(),
        AppRoutes.createAccount: (_) => const CreateAccountScreen(),
        AppRoutes.home: (_) => const HomeScreen(),
        AppRoutes.profile: (_) => const ProfileScreen(),
        AppRoutes.editProfile: (_) => const EditProfileScreen(),
        AppRoutes.changePassword: (_) => const ChangePasswordScreen(),
      },
    );
  }

  /// Allows opening one screen directly during browser-based visual reviews.
  String get _initialRoute {
    if (!kIsWeb) return AppRoutes.login;

    return switch (Uri.base.queryParameters['screen']) {
      'create-account' => AppRoutes.createAccount,
      'home' => AppRoutes.home,
      'profile' => AppRoutes.profile,
      'edit-profile' => AppRoutes.editProfile,
      'change-password' => AppRoutes.changePassword,
      _ => AppRoutes.login,
    };
  }
}

/// Displays the web build inside the iPhone-sized canvas used for reviews.
///
/// On iOS this widget is transparent and therefore does not alter native
/// sizing or safe areas.
class _WebPreviewFrame extends StatelessWidget {
  const _WebPreviewFrame({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!kIsWeb) return child;

    return Scaffold(
      backgroundColor: const Color(0xFF151515),
      body: LayoutBuilder(
        builder: (context, constraints) => Center(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(50),
            child: SizedBox(
              width: constraints.constrainWidth(402),
              height: constraints.constrainHeight(874),
              child: MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(padding: const EdgeInsets.only(top: 47)),
                child: child,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

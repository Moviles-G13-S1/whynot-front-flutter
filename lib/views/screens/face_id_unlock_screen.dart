import 'package:flutter/material.dart';

import '../../app/app_routes.dart';
import '../../app/dependencies_scope.dart';
import '../../controllers/admin_access_controller.dart';
import '../widgets/brand_mark.dart';
import '../widgets/form_controls.dart';

/// Startup gate. Protected routes are not built before local authentication.
class FaceIdUnlockScreen extends StatefulWidget {
  const FaceIdUnlockScreen({super.key});

  @override
  State<FaceIdUnlockScreen> createState() => _FaceIdUnlockScreenState();
}

class _FaceIdUnlockScreenState extends State<FaceIdUnlockScreen> {
  bool _busy = true;
  String? _message;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _unlock(initial: true);
    });
  }

  void _go(String route) {
    if (!mounted) return;
    Navigator.pushNamedAndRemoveUntil(context, route, (_) => false);
  }

  Future<void> _unlock({bool initial = false}) async {
    if (_busy && !initial) return;
    final dependencies = context.dependencies;
    final controller = dependencies.faceIdController;
    final userId = dependencies.authController.currentUser?.id;
    if (userId == null) {
      _go(AppRoutes.login);
      return;
    }
    if (controller == null || !controller.supportedPlatform) {
      _go(AppRoutes.home);
      return;
    }
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      if (initial && !await controller.isEnabled(userId)) {
        if (dependencies.authController.currentUser?.id == userId) {
          _go(AppRoutes.home);
        } else {
          _go(AppRoutes.login);
        }
        return;
      }
      if (!await controller.authenticate()) {
        if (mounted) {
          setState(
            () => _message =
                'Face ID could not unlock WhyNot. Try again or log in with your password.',
          );
        }
        return;
      }
      if (!mounted) return;
      if (dependencies.authController.currentUser?.id != userId) {
        _go(AppRoutes.login);
        return;
      }
      // Offline startup can still open the regular Home screen. Admin access
      // requires a fresh claim check and is never assumed when that fails.
      var access = AdminAccess.regularUser;
      try {
        access = await dependencies.adminAccessController.resolve();
      } catch (_) {
        // Fall back to the existing offline-capable Home, not admin routes.
      }
      if (dependencies.authController.currentUser?.id != userId ||
          access == AdminAccess.signedOut) {
        _go(AppRoutes.login);
        return;
      }
      _go(
        access == AdminAccess.admin ? AppRoutes.adminDashboard : AppRoutes.home,
      );
    } catch (_) {
      if (mounted) {
        setState(
          () => _message =
              'Could not verify Face ID settings. Log in with your password.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _usePassword() async {
    if (_busy) return;
    final auth = context.dependencies.authController;
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      await auth.signOut();
      _go(AppRoutes.login);
    } catch (_) {
      if (auth.currentUser == null) {
        _go(AppRoutes.login);
      } else if (mounted) {
        setState(
          () => _message = 'Could not end the session. Please try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Center(child: BrandMark()),
                  const SizedBox(height: 40),
                  const Icon(Icons.face, size: 64),
                  const SizedBox(height: 16),
                  Text(
                    'Unlock WhyNot',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _message ?? 'Use Face ID to access your account.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  if (_busy)
                    const Center(child: CircularProgressIndicator())
                  else ...[
                    PillButton(
                      label: 'Unlock with Face ID',
                      onPressed: () => _unlock(),
                    ),
                    TextButton(
                      onPressed: _usePassword,
                      child: const Text('Log in with password'),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

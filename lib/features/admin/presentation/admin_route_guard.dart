import 'package:flutter/material.dart';

import '../../../app/app_routes.dart';
import '../application/admin_access.dart';

/// Prevents an administrative screen from being built until the current
/// Firebase token has been verified to contain `admin: true`.
class AdminRouteGuard extends StatefulWidget {
  const AdminRouteGuard({
    required this.child,
    required this.resolveAccess,
    super.key,
  });

  final Widget child;
  final AdminAccessResolver resolveAccess;

  @override
  State<AdminRouteGuard> createState() => _AdminRouteGuardState();
}

class _AdminRouteGuardState extends State<AdminRouteGuard> {
  late Future<AdminAccess> _access;

  @override
  void initState() {
    super.initState();
    _access = widget.resolveAccess();
  }

  void _retry() {
    setState(() {
      _access = widget.resolveAccess();
    });
  }

  void _redirect(AdminAccess access) {
    final destination = access == AdminAccess.signedOut
        ? AppRoutes.login
        : AppRoutes.home;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      Navigator.pushNamedAndRemoveUntil(context, destination, (route) => false);
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<AdminAccess>(
      future: _access,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Scaffold(
            body: SafeArea(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'We could not verify administrative access.',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: _retry,
                        child: const Text('Try again'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }

        if (!snapshot.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final access = snapshot.requireData;
        if (access == AdminAccess.admin) {
          return widget.child;
        }

        _redirect(access);
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      },
    );
  }
}

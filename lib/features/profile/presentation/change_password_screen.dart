import 'package:flutter/material.dart';

import '../../../app/app_routes.dart';
import '../../../app/dependencies_scope.dart';
import '../../../app/whynot_theme.dart';
import '../../authentication/domain/auth_repository.dart';
import '../../../shared/widgets/app_bottom_navigation.dart';
import '../../../shared/widgets/form_controls.dart';
import 'widgets/profile_controls.dart';

/// Form for validating and replacing the current password.
class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _currentController = TextEditingController();
  final _newController = TextEditingController();
  final _confirmController = TextEditingController();

  bool _isUpdating = false;

  List<TextEditingController> get _controllers => [
    _currentController,
    _newController,
    _confirmController,
  ];

  /// Enables submission only when all local password rules are satisfied.
  bool get _isComplete =>
      _currentController.text.isNotEmpty &&
      _newController.text.length >= 8 &&
      _confirmController.text.isNotEmpty &&
      _confirmController.text == _newController.text &&
      !_isUpdating;

  @override
  void initState() {
    super.initState();

    for (final controller in _controllers) {
      controller.addListener(_refresh);
    }
  }

  /// Rebuilds the submit state when any password value changes.
  void _refresh() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    for (final controller in _controllers) {
      controller.dispose();
    }

    super.dispose();
  }

  Future<void> _updatePassword() async {
    if (!_isComplete) return;

    FocusScope.of(context).unfocus();

    if (context.dependencies.authController.currentUser == null) {
      _showMessage('No user is logged in.');
      return;
    }

    final currentPassword = _currentController.text.trim();

    final newPassword = _newController.text.trim();

    final confirmPassword = _confirmController.text.trim();

    if (newPassword.length < 8) {
      _showMessage('New password must have at least 8 characters.');
      return;
    }

    if (newPassword != confirmPassword) {
      _showMessage('New passwords do not match.');
      return;
    }

    if (currentPassword == newPassword) {
      _showMessage(
        'Your new password must be different from your current password.',
      );
      return;
    }

    setState(() => _isUpdating = true);

    try {
      await context.dependencies.authController.changePassword(
        currentPassword: currentPassword,
        newPassword: newPassword,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password updated successfully.')),
      );

      await Future<void>.delayed(const Duration(milliseconds: 700));

      if (!mounted) return;

      Navigator.pop(context);
    } on AuthFailure catch (error) {
      if (!mounted) return;

      String message;

      switch (error.code) {
        case 'wrong-password':
        case 'invalid-credential':
          message = 'Your current password is incorrect.';
          break;

        case 'weak-password':
          message = 'Your new password is too weak.';
          break;

        case 'requires-recent-login':
          message = 'Please log in again before changing your password.';
          break;

        case 'network-request-failed':
          message = 'Check your internet connection and try again.';
          break;

        case 'too-many-requests':
          message = 'Too many attempts. Please try again later.';
          break;

        default:
          message = 'Could not update password. Please try again.';
      }

      _showMessage(message);
    } catch (_) {
      if (!mounted) return;

      _showMessage('Could not update password. Please try again.');
    } finally {
      if (mounted) {
        setState(() => _isUpdating = false);
      }
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  /// Provides direct access to implemented bottom-navigation destinations.
  void _onNavigationSelected(int index) {
    if (index == 0) {
      Navigator.pushNamedAndRemoveUntil(context, AppRoutes.home, (_) => false);
    } else if (index == 1) {
      Navigator.pushNamedAndRemoveUntil(
        context,
        AppRoutes.wishlists,
        (_) => false,
      );
    } else if (index == 2) {
      Navigator.pushNamed(context, AppRoutes.newProductManual);
    } else if (index == 3) {
      Navigator.pushNamedAndRemoveUntil(
        context,
        AppRoutes.purchases,
        (_) => false,
      );
    } else if (index == 4) {
      Navigator.pushNamedAndRemoveUntil(
        context,
        AppRoutes.profile,
        (_) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: WhyNotColors.background,
      body: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 6, 24, 130),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: _isUpdating ? null : () => Navigator.pop(context),
                  style: linkButtonStyle(),
                  child: const Text('‹ Edit Profile'),
                ),
              ),

              const SizedBox(height: 38),

              Center(
                child: Text(
                  'Change Password',
                  style: WhyNotTextStyles.serif(size: 24),
                ),
              ),

              const SizedBox(height: 59),

              FormSurface(
                padding: const EdgeInsets.fromLTRB(9, 25, 9, 41),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    PasswordFieldGroup(
                      label: 'Current password',
                      hint: 'Enter current password',
                      controller: _currentController,
                    ),

                    PasswordFieldGroup(
                      label: 'New password',
                      hint: 'Enter new password',
                      controller: _newController,
                    ),

                    PasswordFieldGroup(
                      label: 'Confirm new password',
                      hint: 'Confirm new password',
                      controller: _confirmController,
                      isLast: true,
                    ),

                    const SizedBox(height: 23),

                    Text(
                      'Use at least 8 characters.',
                      style: WhyNotTextStyles.muted(size: 11),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),

              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: _isUpdating ? null : () => Navigator.pop(context),
                  style: linkButtonStyle(),
                  child: const Text('Cancel'),
                ),
              ),

              const SizedBox(height: 11),

              PillButton(
                label: _isUpdating ? 'Updating...' : 'Update password',
                onPressed: _isComplete ? _updatePassword : null,
              ),

              const SizedBox(height: 10),

              Center(
                child: Text(
                  _statusText,
                  textAlign: TextAlign.center,
                  style: WhyNotTextStyles.muted(size: 11),
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: AppBottomNavigation(
        selectedIndex: 4,
        onSelected: _onNavigationSelected,
      ),
    );
  }

  String get _statusText {
    if (_isUpdating) {
      return 'Updating your password...';
    }

    if (_newController.text.isNotEmpty && _newController.text.length < 8) {
      return 'Password must have at least 8 characters';
    }

    if (_confirmController.text.isNotEmpty &&
        _confirmController.text != _newController.text) {
      return 'Passwords do not match';
    }

    if (_isComplete) {
      return 'Ready to update your password';
    }

    return 'Complete all fields to continue';
  }
}

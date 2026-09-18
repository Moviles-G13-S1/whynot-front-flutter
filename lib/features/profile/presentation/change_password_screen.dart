import 'package:flutter/material.dart';

import '../../../app/app_routes.dart';
import '../../../app/whynot_theme.dart';
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

  /// Enables submission only when all local password rules are satisfied.
  bool get _isComplete =>
      _currentController.text.isNotEmpty &&
      _newController.text.length >= 8 &&
      _confirmController.text == _newController.text;

  @override
  void initState() {
    super.initState();
    for (final controller in _controllers) {
      controller.addListener(_refresh);
    }
  }

  List<TextEditingController> get _controllers => [
    _currentController,
    _newController,
    _confirmController,
  ];

  /// Rebuilds the submit state when any password value changes.
  void _refresh() => setState(() {});

  @override
  void dispose() {
    for (final controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  /// Confirms the prototype update and returns to the profile.
  void _updatePassword() {
    if (!_isComplete) return;
    FocusScope.of(context).unfocus();
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Password updated')));
    Navigator.pop(context);
  }

  /// Provides direct access to implemented bottom-navigation destinations.
  void _onNavigationSelected(int index) {
    if (index == 0) {
      Navigator.pushNamedAndRemoveUntil(context, AppRoutes.home, (_) => false);
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
                  onPressed: () => Navigator.pop(context),
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
                  onPressed: () => Navigator.pop(context),
                  style: linkButtonStyle(),
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(height: 11),
              PillButton(
                label: 'Update password',
                onPressed: _isComplete ? _updatePassword : null,
              ),
              const SizedBox(height: 10),
              Center(
                child: Text(
                  _isComplete
                      ? 'Ready to update your password'
                      : 'Complete all fields to continue',
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
}

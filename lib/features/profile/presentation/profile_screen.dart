import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../app/app_routes.dart';
import '../../../app/whynot_theme.dart';
import '../../../shared/widgets/app_bottom_navigation.dart';
import '../../../shared/widgets/form_controls.dart';
import 'widgets/profile_controls.dart';

/// Read-only summary of the current user's account data.
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  /// Handles only destinations currently represented by real screens.
  void _onNavigationSelected(BuildContext context, int index) {
    if (index == 0) {
      Navigator.pushReplacementNamed(context, AppRoutes.home);
    } else if (index == 2) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Add a new item')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 39, 24, 130),
          child: Column(
            children: [
              const ProfileAvatar(),
              const SizedBox(height: 31),
              Text('Juliana Durán', style: WhyNotTextStyles.serif(size: 30)),
              const SizedBox(height: 45),
              FormSurface(
                padding: const EdgeInsets.fromLTRB(27, 24, 27, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const ProfileValue(
                      label: 'Email',
                      value: 'j.duranl@uniandes.edu.co',
                    ),
                    const ProfileValue(label: 'Gender', value: 'Female'),
                    const ProfileValue(label: 'Age', value: '22'),
                    ProfileValue(
                      label: 'Password',
                      value: '********',
                      onTap: () => Navigator.pushNamed(
                        context,
                        AppRoutes.changePassword,
                      ),
                    ),
                    const ProfileValue(
                      label: 'Preferred Category',
                      value: 'Beauty',
                      isLast: true,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 30),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () =>
                      Navigator.pushNamed(context, AppRoutes.editProfile),
                  style: linkButtonStyle(),
                  icon: SvgPicture.asset(
                    'assets/figma/edit_profile.svg',
                    width: 13,
                    height: 13,
                  ),
                  label: const Text('Edit Profile'),
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: AppBottomNavigation(
        selectedIndex: 4,
        onSelected: (index) => _onNavigationSelected(context, index),
      ),
    );
  }
}

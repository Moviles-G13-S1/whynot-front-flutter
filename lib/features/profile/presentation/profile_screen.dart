import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../app/app_routes.dart';
import '../../../app/dependencies_scope.dart';
import '../../../app/whynot_theme.dart';
import '../../../shared/domain/category_catalog.dart';
import '../../../shared/widgets/app_bottom_navigation.dart';
import '../../../shared/widgets/form_controls.dart';
import 'widgets/profile_controls.dart';
import '../domain/user_profile.dart';

/// Read-only summary of the current user's account data.
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.dependencies.profileController;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: controller.currentUserId == null
            ? const Center(child: Text('No user logged in.'))
            : StreamBuilder<UserProfile?>(
                stream: controller.watchCurrentProfile(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (snapshot.hasError) {
                    return const Center(child: Text('Could not load profile.'));
                  }

                  if (!snapshot.hasData) {
                    return const Center(child: Text('Profile not found.'));
                  }

                  final profile = snapshot.data!;
                  final name = profile.name.isEmpty ? 'User' : profile.name;
                  final email = profile.email;
                  final gender = profile.gender;
                  final age = profile.age.toString();
                  final preferredCategory =
                      CategoryCatalog.labelsById[profile.preferredCategoryId] ??
                      'Not selected';

                  return SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(24, 39, 24, 130),
                    child: Column(
                      children: [
                        const ProfileAvatar(),
                        const SizedBox(height: 31),
                        Text(name, style: WhyNotTextStyles.serif(size: 30)),
                        const SizedBox(height: 45),
                        FormSurface(
                          padding: const EdgeInsets.fromLTRB(27, 24, 27, 24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              ProfileValue(label: 'Email', value: email),
                              ProfileValue(label: 'Gender', value: gender),
                              ProfileValue(label: 'Age', value: age),
                              ProfileValue(
                                label: 'Password',
                                value: '********',
                                onTap: () => Navigator.pushNamed(
                                  context,
                                  AppRoutes.changePassword,
                                ),
                              ),
                              ProfileValue(
                                label: 'Preferred Category',
                                value: preferredCategory,
                                isLast: true,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 30),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton.icon(
                            onPressed: () => Navigator.pushNamed(
                              context,
                              AppRoutes.editProfile,
                            ),
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
                  );
                },
              ),
      ),
      bottomNavigationBar: const AppBottomNavigation(selectedIndex: 4),
    );
  }
}

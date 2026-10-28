import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../app/app_routes.dart';
import '../../app/dependencies_scope.dart';
import '../../app/whynot_theme.dart';
import '../../models/category_catalog.dart';
import '../../models/city.dart';
import '../../controllers/live_section.dart';
import '../../controllers/profile_load_controller.dart';
import '../widgets/app_bottom_navigation.dart';
import '../widgets/form_controls.dart';
import '../widgets/profile_controls.dart';

/// Read-only summary of the current user's account data.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  ProfileLoadController? _loads;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loads ??= ProfileLoadController(
      watchProfile: context.dependencies.profileController.watchCurrentProfile,
      getCities: context.dependencies.cityController.getCities,
    );
  }

  @override
  void dispose() {
    _loads?.dispose();
    super.dispose();
  }

  Future<void> _logOut(BuildContext context) async {
    try {
      await context.dependencies.authController.signOut();

      if (!context.mounted) return;

      Navigator.pushNamedAndRemoveUntil(
        context,
        AppRoutes.login,
        (route) => false,
      );
    } catch (_) {
      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not log out. Please try again.')),
      );
    }
  }

  // Santiago Casasbuenas: Display the saved profile image in the summary.
  @override
  Widget build(BuildContext context) {
    final controller = context.dependencies.profileController;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: controller.currentUserId == null
            ? const Center(child: Text('No user logged in.'))
            : AnimatedBuilder(
                animation: _loads!.profile,
                builder: (context, _) {
                  final snapshot = _loads!.profile.snapshot;
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (snapshot.hasError) {
                    return Center(
                      child: TextButton(
                        onPressed: _loads!.profile.start,
                        child: const Text('Could not load profile. Try again'),
                      ),
                    );
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
                        ProfileAvatar(
                          photoPath: profile.photoPath,
                          loadPhotoUrl: controller.getPhotoUrl,
                        ),
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
                              if (profile.cityId == null)
                                const ProfileValue(
                                  label: 'City',
                                  value: 'Not selected',
                                )
                              else
                                _ProfileCityValue(
                                  cityId: profile.cityId!,
                                  cities: _loads!.cities,
                                ),
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

                        const SizedBox(height: 38),

                        SizedBox(
                          width: 190,
                          child: PillButton(
                            label: 'Log Out',
                            onPressed: () => _logOut(context),
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

class _ProfileCityValue extends StatelessWidget {
  const _ProfileCityValue({required this.cityId, required this.cities});

  final String cityId;
  final LiveSection<List<City>> cities;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: cities,
    builder: (context, _) {
      final snapshot = cities.snapshot;
      if (snapshot.hasError) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const ProfileValue(label: 'City', value: 'City unavailable'),
            TextButton(
              onPressed: cities.start,
              child: const Text('Retry city'),
            ),
          ],
        );
      }
      final city = snapshot.data
          ?.where((item) => item.id == cityId)
          .firstOrNull;

      return ProfileValue(
        label: 'City',
        value:
            city?.name ??
            (snapshot.connectionState == ConnectionState.waiting
                ? 'Loading city...'
                : 'City unavailable'),
      );
    },
  );
}

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
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

  String _categoryLabel(String? categoryId) {
    const categories = {
      'fashion': 'Fashion',
      'beauty': 'Beauty',
      'technology': 'Technology',
      'home': 'Home',
      'accessories': 'Accessories',
      'travel': 'Travel',
      'gifts': 'Gifts',
      'other': 'Other',
    };

    return categories[categoryId] ?? 'Not selected';
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: user == null
            ? const Center(
                child: Text('No user logged in.'),
              )
            : StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                stream: FirebaseFirestore.instance
                    .collection('users')
                    .doc(user.uid)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(),
                    );
                  }

                  if (snapshot.hasError) {
                    return const Center(
                      child: Text('Could not load profile.'),
                    );
                  }

                  if (!snapshot.hasData || !snapshot.data!.exists) {
                    return const Center(
                      child: Text('Profile not found.'),
                    );
                  }

                  final data = snapshot.data!.data()!;

                  final name = data['name'] as String? ?? 'User';
                  final email =
                      data['email'] as String? ?? user.email ?? '';
                  final gender = data['gender'] as String? ?? '';
                  final age = data['age']?.toString() ?? '';
                  final preferredCategory =
                      _categoryLabel(data['preferredCategoryId'] as String?);

                  return SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(24, 39, 24, 130),
                    child: Column(
                      children: [
                        const ProfileAvatar(),
                        const SizedBox(height: 31),
                        Text(
                          name,
                          style: WhyNotTextStyles.serif(size: 30),
                        ),
                        const SizedBox(height: 45),
                        FormSurface(
                          padding:
                              const EdgeInsets.fromLTRB(27, 24, 27, 24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              ProfileValue(
                                label: 'Email',
                                value: email,
                              ),
                              ProfileValue(
                                label: 'Gender',
                                value: gender,
                              ),
                              ProfileValue(
                                label: 'Age',
                                value: age,
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
                      ],
                    ),
                  );
                },
              ),
      ),
      bottomNavigationBar: const AppBottomNavigation(
        selectedIndex: 4,
      ),
    );
  }
}
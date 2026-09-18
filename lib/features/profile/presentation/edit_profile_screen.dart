import 'package:flutter/material.dart';

import '../../../app/app_routes.dart';
import '../../../app/whynot_theme.dart';
import '../../../shared/widgets/app_bottom_navigation.dart';
import '../../../shared/widgets/form_controls.dart';
import 'widgets/profile_controls.dart';

/// Form for editing the fields displayed in the profile summary.
class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  static const _initialName = 'Juliana Durán';
  static const _initialEmail = 'j.duranl@uniandes.edu.co';
  static const _initialAge = '22';
  static const _initialGender = 'Female';
  static const _initialCategory = 'Beauty';

  final _nameController = TextEditingController(text: _initialName);
  final _emailController = TextEditingController(text: _initialEmail);
  final _ageController = TextEditingController(text: _initialAge);
  String? _gender = _initialGender;
  String? _category = _initialCategory;

  List<TextEditingController> get _controllers => [
    _nameController,
    _emailController,
    _ageController,
  ];

  bool get _hasChanges =>
      _nameController.text != _initialName ||
      _emailController.text != _initialEmail ||
      _ageController.text != _initialAge ||
      _gender != _initialGender ||
      _category != _initialCategory;

  @override
  void initState() {
    super.initState();
    for (final controller in _controllers) {
      controller.addListener(_refresh);
    }
  }

  /// Updates the save state whenever a form value changes.
  void _refresh() => setState(() {});

  @override
  void dispose() {
    for (final controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  /// Confirms the prototype update and returns to the profile summary.
  void _save() {
    if (!_hasChanges) return;
    FocusScope.of(context).unfocus();
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Profile updated')));
    Navigator.pop(context);
  }

  /// Keeps bottom navigation consistent with the other profile screens.
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
                  child: const Text('‹ Profile'),
                ),
              ),
              const SizedBox(height: 12),
              Center(
                child: Text(
                  'Edit Profile',
                  style: WhyNotTextStyles.serif(size: 24),
                ),
              ),
              const SizedBox(height: 18),
              const Center(child: ProfileAvatar(size: 72)),
              const SizedBox(height: 8),
              Center(
                child: TextButton(
                  onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Photo picker coming soon')),
                  ),
                  style: linkButtonStyle(),
                  child: const Text('Change photo'),
                ),
              ),
              const SizedBox(height: 12),
              FormSurface(
                padding: const EdgeInsets.fromLTRB(9, 16, 9, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _field('Name', DesignField(controller: _nameController)),
                    _field(
                      'Email',
                      DesignField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                      ),
                    ),
                    _field(
                      'Gender',
                      DesignDropdown(
                        value: _gender,
                        items: const ['Female', 'Male', 'Other'],
                        onChanged: (value) => setState(() => _gender = value),
                      ),
                    ),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 2,
                          child: _field(
                            'Age',
                            DesignField(
                              controller: _ageController,
                              keyboardType: TextInputType.number,
                            ),
                            bottom: 0,
                          ),
                        ),
                        const SizedBox(width: 15),
                        Expanded(
                          flex: 3,
                          child: _field(
                            'Preferred Category',
                            DesignDropdown(
                              value: _category,
                              items: const ['Beauty', 'Clothes', 'Tech'],
                              onChanged: (value) =>
                                  setState(() => _category = value),
                            ),
                            bottom: 0,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    InkWell(
                      onTap: () => Navigator.pushNamed(
                        context,
                        AppRoutes.changePassword,
                      ),
                      borderRadius: BorderRadius.circular(8),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 8,
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Change password',
                                style: WhyNotTextStyles.muted(size: 15),
                              ),
                            ),
                            Text('›', style: WhyNotTextStyles.muted(size: 20)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),
              TextButton(
                onPressed: () => Navigator.pop(context),
                style: linkButtonStyle(),
                child: const Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Cancel'),
                ),
              ),
              const SizedBox(height: 14),
              PillButton(
                label: 'Save changes',
                height: 42,
                onPressed: _hasChanges ? _save : null,
              ),
              const SizedBox(height: 8),
              Center(
                child: Text(
                  _hasChanges ? 'Changes ready to save' : 'No changes to save',
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

  /// Builds the repeated label, spacing and control pattern from the design.
  Widget _field(String label, Widget child, {double bottom = 12}) {
    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 7),
            child: FieldLabel(label),
          ),
          const SizedBox(height: 4),
          child,
        ],
      ),
    );
  }
}

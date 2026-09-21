import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
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
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _ageController = TextEditingController();

  String? _gender;
  String? _category;

  String _initialName = '';
  String _initialEmail = '';
  String _initialAge = '';
  String? _initialGender;
  String? _initialCategory;

  bool _isLoading = true;
  bool _isSaving = false;

  static const Map<String, String> _categoryIds = {
    'Fashion': 'fashion',
    'Beauty': 'beauty',
    'Technology': 'technology',
    'Home': 'home',
    'Accessories': 'accessories',
    'Travel': 'travel',
    'Gifts': 'gifts',
    'Other': 'other',
  };

  static const Map<String, String> _categoryLabels = {
    'fashion': 'Fashion',
    'beauty': 'Beauty',
    'technology': 'Technology',
    'home': 'Home',
    'accessories': 'Accessories',
    'travel': 'Travel',
    'gifts': 'Gifts',
    'other': 'Other',
  };

  List<TextEditingController> get _controllers => [
        _nameController,
        _emailController,
        _ageController,
      ];

  bool get _hasChanges {
    if (_isLoading) return false;

    return _nameController.text.trim() != _initialName ||
        _ageController.text.trim() != _initialAge ||
        _gender != _initialGender ||
        _category != _initialCategory;
  }

  @override
  void initState() {
    super.initState();

    for (final controller in _controllers) {
      controller.addListener(_refresh);
    }

    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
      return;
    }

    try {
      final document = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      final data = document.data();

      if (data == null) {
        if (mounted) {
          setState(() => _isLoading = false);
        }
        return;
      }

      final name = data['name'] as String? ?? '';
      final email = data['email'] as String? ?? user.email ?? '';
      final age = data['age']?.toString() ?? '';
      final gender = data['gender'] as String?;
      final categoryId = data['preferredCategoryId'] as String?;
      final category = _categoryLabels[categoryId];

      _initialName = name;
      _initialEmail = email;
      _initialAge = age;
      _initialGender = gender;
      _initialCategory = category;

      _nameController.text = name;
      _emailController.text = email;
      _ageController.text = age;
      _gender = gender;
      _category = category;

      if (mounted) {
        setState(() => _isLoading = false);
      }
    } catch (_) {
      if (!mounted) return;

      setState(() => _isLoading = false);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not load profile.'),
        ),
      );
    }
  }

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

  Future<void> _save() async {
    if (!_hasChanges || _isSaving) return;

    FocusScope.of(context).unfocus();

    final user = FirebaseAuth.instance.currentUser;
    final age = int.tryParse(_ageController.text.trim());

    if (user == null) {
      _showMessage('No user logged in.');
      return;
    }

    if (_nameController.text.trim().isEmpty ||
        age == null ||
        _gender == null ||
        _category == null) {
      _showMessage('Please complete all fields.');
      return;
    }

    setState(() => _isSaving = true);

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update({
        'name': _nameController.text.trim(),
        'gender': _gender,
        'age': age,
        'preferredCategoryId': _categoryIds[_category],
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profile updated'),
        ),
      );

      Navigator.pop(context);
    } catch (_) {
      if (!mounted) return;

      _showMessage('Could not update profile. Please try again.');
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  /// Keeps bottom navigation consistent with the other profile screens.
  void _onNavigationSelected(int index) {
    if (index == 0) {
      Navigator.pushNamedAndRemoveUntil(
        context,
        AppRoutes.home,
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
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

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
              const Center(
                child: ProfileAvatar(size: 72),
              ),
              const SizedBox(height: 8),
              Center(
                child: TextButton(
                  onPressed: () =>
                      ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Photo picker coming soon'),
                    ),
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
                    _field(
                      'Name',
                      DesignField(
                        controller: _nameController,
                      ),
                    ),

                    // Email is displayed but not updated yet.
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
                        items: const [
                          'Female',
                          'Male',
                          'Other',
                        ],
                        onChanged: (value) =>
                            setState(() => _gender = value),
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
                              items: const [
                                'Fashion',
                                'Beauty',
                                'Technology',
                                'Home',
                                'Accessories',
                                'Travel',
                                'Gifts',
                                'Other',
                              ],
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
                            Text(
                              '›',
                              style: WhyNotTextStyles.muted(size: 20),
                            ),
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
                label: _isSaving ? 'Saving...' : 'Save changes',
                height: 42,
                onPressed: _hasChanges && !_isSaving ? _save : null,
              ),
              const SizedBox(height: 8),
              Center(
                child: Text(
                  _hasChanges
                      ? 'Changes ready to save'
                      : 'No changes to save',
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

  Widget _field(
    String label,
    Widget child, {
    double bottom = 12,
  }) {
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
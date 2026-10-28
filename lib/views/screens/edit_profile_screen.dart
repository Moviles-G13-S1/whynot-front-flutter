import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/services.dart';

import '../../app/app_routes.dart';
import '../../app/dependencies_scope.dart';
import '../../app/whynot_theme.dart';
import '../../models/category_catalog.dart';
import '../../models/city.dart';
import '../widgets/app_bottom_navigation.dart';
import '../widgets/city_selector.dart';
import '../widgets/form_controls.dart';
import '../widgets/profile_controls.dart';
import '../../models/user_profile.dart';
import '../../models/input_policy.dart';
import '../../models/profile_photo.dart';
import '../../models/network_failure.dart';
import '../../controllers/connection_recovery.dart';
import '../widgets/offline_notice.dart';

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
  final _cityController = TextEditingController();

  String? _gender;
  String? _category;
  String? _cityId;
  List<City> _cities = const [];

  String _initialName = '';
  String _initialAge = '';
  String? _initialGender;
  String? _initialCategory;
  String? _initialCityId;

  bool _isLoading = true;
  bool _isSaving = false;
  bool _isUploadingPhoto = false;
  String? _photoPath;
  ProfilePhoto? _photoPreview;
  bool _profileRequested = false;
  bool _loadFailed = false;
  bool _citiesFailed = false;
  ConnectionRecovery? _recovery;
  List<String> _lastInputs = const [];

  List<TextEditingController> get _controllers => [
    _nameController,
    _emailController,
    _ageController,
    _cityController,
  ];

  bool get _hasChanges {
    if (_isLoading) return false;

    return _nameController.text.trim() != _initialName ||
        _ageController.text.trim() != _initialAge ||
        _gender != _initialGender ||
        _category != _initialCategory ||
        _cityId != _initialCityId;
  }

  @override
  void initState() {
    super.initState();

    for (final controller in _controllers) {
      controller.addListener(_refresh);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _recovery ??= ConnectionRecovery(context.dependencies.connectivity, () {
      if (_loadFailed && !_isLoading) {
        _loadProfile();
      } else if (_citiesFailed && !_isLoading) {
        _reloadCities();
      }
    });
    if (!_profileRequested) {
      _profileRequested = true;
      _loadProfile();
    }
  }

  // Santiago Casasbuenas: Load the current photo path with profile fields.
  Future<void> _loadProfile() async {
    setState(() {
      _isLoading = true;
      _loadFailed = false;
    });
    final profileController = context.dependencies.profileController;
    if (profileController.currentUserId == null) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
      return;
    }

    try {
      // City failure must not discard a successfully loaded profile.
      final citiesFuture = context.dependencies.cityController.getCities().then(
        (cities) {
          _citiesFailed = cities.isEmpty;
          return cities;
        },
        onError: (Object _) {
          _citiesFailed = true;
          return <City>[];
        },
      );
      final profileFuture = profileController.getCurrentProfile();
      final results = await (citiesFuture, profileFuture).wait;
      final cities = results.$1;
      final profile = results.$2;
      if (!mounted) return;
      if (profile == null) {
        if (mounted) {
          setState(() {
            _isLoading = false;
            _loadFailed = true;
          });
        }
        return;
      }

      final name = profile.name;
      final email = profile.email;
      final age = profile.age.toString();
      final gender = profile.gender;
      final category = CategoryCatalog.labelsById[profile.preferredCategoryId];
      final city = cities
          .where((item) => item.id == profile.cityId)
          .firstOrNull;

      _photoPath = profile.photoPath;
      _initialName = name;
      _initialAge = age;
      _initialGender = gender;
      _initialCategory = category;
      _initialCityId = profile.cityId;

      _nameController.text = name;
      _emailController.text = email;
      _ageController.text = age;
      _gender = gender;
      _category = category;
      _cities = cities;
      _cityId = profile.cityId;
      _cityController.text = city?.name ?? '';

      if (mounted) {
        setState(() => _isLoading = false);
      }
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _loadFailed = true;
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Could not load profile.')));
    }
  }

  void _refresh() {
    // DropdownMenu also updates cursor/selection during layout. Only text
    // changes affect save eligibility and require rebuilding this form.
    final inputs = _controllers.map((controller) => controller.text).toList();
    if (listEquals(inputs, _lastInputs)) return;
    _lastInputs = inputs;
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _recovery?.dispose();
    for (final controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_hasChanges || _isSaving) return;

    FocusScope.of(context).unfocus();

    final age = int.tryParse(_ageController.text.trim());
    final selectedCity = _cities
        .where((city) => city.id == _cityId)
        .firstOrNull;

    if (context.dependencies.profileController.currentUserId == null) {
      _showMessage('No user logged in.');
      return;
    }

    if (InputPolicy.containsEmoji(_nameController.text)) {
      _showMessage('Name cannot contain emoji.');
      return;
    }
    if (InputPolicy.containsEmoji(_cityController.text)) {
      _showMessage('City search cannot contain emoji.');
      return;
    }
    if (_nameController.text.trim().length >
        UserProfileConstraints.maximumNameLength) {
      _showMessage(
        'Name must have at most ${UserProfileConstraints.maximumNameLength} characters.',
      );
      return;
    }

    if (_nameController.text.trim().isEmpty ||
        age == null ||
        selectedCity == null ||
        _cityController.text.trim() != selectedCity.name ||
        _gender == null ||
        _category == null) {
      _showMessage('Please complete all fields.');
      return;
    }

    if (age < UserProfileConstraints.minimumAge ||
        age > UserProfileConstraints.maximumAge) {
      _showMessage(
        'Age must be between ${UserProfileConstraints.minimumAge} and '
        '${UserProfileConstraints.maximumAge}.',
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      await context.dependencies.profileController.updateCurrentProfile(
        UserProfileUpdate(
          name: _nameController.text.trim(),
          gender: _gender!,
          age: age,
          preferredCategoryId: CategoryCatalog.idsByLabel[_category]!,
          cityId: selectedCity.id,
        ),
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('Profile updated')));

      Navigator.pop(context);
    } on InputPolicyException catch (error) {
      if (mounted) _showMessage(error.message);
    } on NetworkFailure catch (error) {
      if (mounted) _showMessage(error.message);
    } catch (_) {
      if (!mounted) return;

      _showMessage(
        'Could not confirm your profile update. Your inputs are still here. Check your connection and try again.',
      );
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  // Santiago Casasbuenas: Preview the selected image and report upload results.
  Future<void> _changePhoto() async {
    if (_isUploadingPhoto) return;
    final controller = context.dependencies.profileController;
    if (controller.currentUserId == null) {
      _showMessage('No user logged in.');
      return;
    }
    try {
      final photo = await controller.pickPhoto();
      if (photo == null || !mounted) return;
      setState(() {
        _photoPreview = photo;
        _isUploadingPhoto = true;
      });
      final path = await controller.savePhoto(photo);
      if (!mounted) return;
      setState(() {
        _photoPreview = null;
        _photoPath = path;
        _isUploadingPhoto = false;
      });
      _showMessage('Photo updated');
    } on FormatException catch (error) {
      if (mounted) {
        _showMessage(error.message);
      }
    } on NetworkFailure catch (error) {
      if (mounted) _showMessage(error.message);
    } catch (_) {
      if (mounted) {
        _showMessage('Could not update photo. Please try again.');
      }
    } finally {
      if (mounted) {
        setState(() {
          _photoPreview = null;
          _isUploadingPhoto = false;
        });
      }
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _reloadCities() async {
    try {
      final cities = await context.dependencies.cityController.getCities();
      if (!mounted) return;
      setState(() {
        _cities = cities;
        _citiesFailed = cities.isEmpty;
        final selected = cities.where((city) => city.id == _cityId).firstOrNull;
        if (selected != null && _cityController.text.isEmpty) {
          _cityController.text = selected.name;
        }
      });
    } catch (_) {
      if (mounted) {
        _showMessage(
          'Cities are unavailable. Your edits are still here. Try again when connected.',
        );
      }
    }
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

  // Santiago Casasbuenas: Show photo preview and upload state on the form.
  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_loadFailed) {
      return Scaffold(
        body: SafeArea(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Profile is unavailable. Connect and try again.'),
                TextButton(
                  onPressed: _loadProfile,
                  child: const Text('Retry profile'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Back to profile'),
                ),
              ],
            ),
          ),
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
              OfflineNotice(
                message: _isSaving
                    ? 'Your submitted changes are waiting for server confirmation. Keep this form open; confirmation resumes when connected.'
                    : 'You can edit the available information here. Reconnect before saving; your unsaved inputs stay in this open form.',
              ),
              if (_citiesFailed)
                TextButton(
                  onPressed: _reloadCities,
                  child: const Text('Cities unavailable. Retry cities'),
                ),
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
              Center(
                child: ProfileAvatar(
                  size: 72,
                  photoPath: _photoPath,
                  loadPhotoUrl:
                      context.dependencies.profileController.getPhotoUrl,
                  loadPhotoBytes:
                      context.dependencies.profileController.getPhotoBytes,
                  connectivity: context.dependencies.connectivity,
                  cacheManager: context.dependencies.photoCacheManager,
                  preview: _photoPreview?.bytes,
                ),
              ),
              const SizedBox(height: 8),
              Center(
                child: TextButton(
                  onPressed: _isUploadingPhoto ? null : _changePhoto,
                  style: linkButtonStyle(),
                  child: Text(
                    _isUploadingPhoto ? 'Uploading photo...' : 'Change photo',
                  ),
                ),
              ),
              const SizedBox(height: 12),
              FormSurface(
                padding: const EdgeInsets.fromLTRB(9, 16, 9, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _field('Name', DesignField(controller: _nameController)),

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
                        items: const ['Female', 'Male', 'Other'],
                        onChanged: (value) => setState(() => _gender = value),
                      ),
                    ),
                    _field(
                      'City',
                      CitySelector(
                        cities: _cities,
                        controller: _cityController,
                        selectedId: _cityId,
                        onSelected: (id) => setState(() => _cityId = id),
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
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                              ],
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
                label: _isSaving ? 'Saving...' : 'Save changes',
                height: 42,
                onPressed: _hasChanges && !_isSaving ? _save : null,
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

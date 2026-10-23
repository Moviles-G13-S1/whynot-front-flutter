import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/app_routes.dart';
import '../../app/dependencies_scope.dart';
import '../../app/whynot_theme.dart';
import '../../models/category_catalog.dart';
import '../../models/city.dart';
import '../widgets/brand_mark.dart';
import '../widgets/city_selector.dart';
import '../widgets/form_controls.dart';
import '../../models/user_profile.dart';
import '../../models/input_policy.dart';
import '../widgets/account_field.dart';
import '../../models/repositories/auth_repository.dart';

/// Registration form for new WhyNot users.
class CreateAccountScreen extends StatefulWidget {
  const CreateAccountScreen({super.key});

  @override
  State<CreateAccountScreen> createState() => _CreateAccountScreenState();
}

class _CreateAccountScreenState extends State<CreateAccountScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _ageController = TextEditingController();
  final _cityController = TextEditingController();
  final _passwordController = TextEditingController();

  String? _gender;
  String? _category;
  String? _cityId;
  List<City> _cities = const [];
  bool _citiesLoading = true;
  bool _citiesRequested = false;
  bool _citiesError = false;
  bool _isLoading = false;
  String? _nameError;
  String? _emailError;
  String? _genderError;
  String? _ageError;
  String? _cityError;
  String? _passwordError;
  String? _categoryError;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_citiesRequested) {
      _citiesRequested = true;
      _loadCities();
    }
  }

  Future<void> _loadCities() async {
    try {
      final cities = await context.dependencies.cityController.getCities();
      if (!mounted) return;
      setState(() {
        _cities = cities;
        _citiesLoading = false;
        _citiesError = cities.isEmpty;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _citiesLoading = false;
        _citiesError = true;
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _ageController.dispose();
    _cityController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _createAccount() async {
    FocusScope.of(context).unfocus();

    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final age = int.tryParse(_ageController.text.trim());
    final selectedCity = _cities
        .where((city) => city.id == _cityId)
        .firstOrNull;
    final nameError = InputPolicy.nameValidationError(
      name,
      maxLength: UserProfileConstraints.maximumNameLength,
    );
    final emailError = InputPolicy.emailValidationError(email);
    final passwordError = InputPolicy.passwordValidationError(
      password,
      requireMinimumLength: true,
    );
    final ageError = _ageValidationError(_ageController.text);
    final cityText = _cityController.text.trim();
    final cityError = InputPolicy.containsEmoji(cityText)
        ? 'You cannot include emojis in your city.'
        : selectedCity == null || cityText != selectedCity.name
        ? 'Select a city from the list.'
        : null;
    final genderError = _gender == null ? 'Select a gender.' : null;
    final categoryError = _category == null
        ? 'Select a preferred category.'
        : null;

    setState(() {
      _nameError = nameError;
      _emailError = emailError;
      _passwordError = passwordError;
      _ageError = ageError;
      _cityError = cityError;
      _genderError = genderError;
      _categoryError = categoryError;
    });

    if (nameError != null ||
        emailError != null ||
        passwordError != null ||
        ageError != null ||
        cityError != null ||
        genderError != null ||
        categoryError != null) {
      return;
    }

    setState(() => _isLoading = true);

    try {
      await context.dependencies.authController.createAccount(
        name: name,
        email: email,
        password: password,
        gender: _gender!,
        age: age!,
        preferredCategoryId: CategoryCatalog.idsByLabel[_category]!,
        cityId: selectedCity!.id,
      );

      if (!mounted) return;

      Navigator.pushNamedAndRemoveUntil(context, AppRoutes.home, (_) => false);
    } on InputPolicyException catch (error) {
      if (mounted) _showMessage(error.message);
    } on AuthFailure catch (error) {
      if (!mounted) return;

      switch (error.code) {
        case 'invalid-name':
          setState(
            () => _nameError =
                'Name cannot exceed '
                '${UserProfileConstraints.maximumNameLength} characters.',
          );
          break;
        case 'invalid-age':
          setState(
            () => _ageError =
                'Age must be between ${UserProfileConstraints.minimumAge} and '
                '${UserProfileConstraints.maximumAge}.',
          );
          break;
        case 'weak-password':
          setState(
            () => _passwordError =
                'Password must be at least '
                '${InputPolicy.minimumPasswordLength} characters.',
          );
          break;
        case 'email-already-in-use':
          setState(
            () => _emailError = 'An account already exists with this email.',
          );
          break;
        case 'invalid-email':
          setState(() => _emailError = 'Enter a valid email address.');
          break;
        default:
          _showMessage('Could not create the account. Please try again.');
      }
    } catch (_) {
      if (!mounted) return;
      _showMessage('Something went wrong. Please try again.');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  String? _ageValidationError(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return 'Age is required.';
    final age = int.tryParse(trimmed);
    if (age == null) return 'Enter a valid age.';
    if (age < UserProfileConstraints.minimumAge ||
        age > UserProfileConstraints.maximumAge) {
      return 'Age must be between ${UserProfileConstraints.minimumAge} and '
          '${UserProfileConstraints.maximumAge}.';
    }
    return null;
  }

  void _revalidateName(String value) {
    if (_nameError == null) return;
    setState(
      () => _nameError = InputPolicy.nameValidationError(
        value,
        maxLength: UserProfileConstraints.maximumNameLength,
      ),
    );
  }

  void _revalidateEmail(String value) {
    if (_emailError == null) return;
    setState(() => _emailError = InputPolicy.emailValidationError(value));
  }

  void _revalidatePassword(String value) {
    if (_passwordError == null) return;
    setState(
      () => _passwordError = InputPolicy.passwordValidationError(
        value,
        requireMinimumLength: true,
      ),
    );
  }

  void _revalidateAge(String value) {
    if (_ageError == null) return;
    setState(() => _ageError = _ageValidationError(value));
  }

  Future<void> _goBack() async {
    if (await Navigator.maybePop(context)) return;
    if (mounted) {
      Navigator.pushReplacementNamed(context, AppRoutes.login);
    }
  }

  @override
  Widget build(BuildContext context) {
    final safeTop = MediaQuery.paddingOf(context).top;
    final topSpace = (80 - safeTop).clamp(24.0, 80.0).toDouble();

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(22, 0, 22, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: IconButton(
                  tooltip: 'Back',
                  onPressed: _goBack,
                  icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
                ),
              ),
              SizedBox(height: topSpace),
              const Center(child: BrandMark()),
              const SizedBox(height: 27),
              Center(
                child: Text(
                  'Create an account',
                  style: WhyNotTextStyles.muted(size: 15),
                ),
              ),
              const SizedBox(height: 37),
              FormSurface(
                padding: const EdgeInsets.fromLTRB(7, 12, 7, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    AccountField(
                      label: 'Name',
                      errorText: _nameError,
                      child: DesignField(
                        controller: _nameController,
                        autofillHints: const [AutofillHints.name],
                        onChanged: _revalidateName,
                        hasError: _nameError != null,
                      ),
                    ),
                    AccountField(
                      label: 'Email',
                      errorText: _emailError,
                      child: DesignField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        autofillHints: const [AutofillHints.email],
                        onChanged: _revalidateEmail,
                        hasError: _emailError != null,
                      ),
                    ),
                    AccountField(
                      label: 'Gender',
                      errorText: _genderError,
                      child: DesignDropdown(
                        value: _gender,
                        items: const ['Female', 'Male', 'Other'],
                        hasError: _genderError != null,
                        onChanged: (value) => setState(() {
                          _gender = value;
                          _genderError = null;
                        }),
                      ),
                    ),
                    AccountField(
                      label: 'Age',
                      errorText: _ageError,
                      child: DesignField(
                        controller: _ageController,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        onChanged: _revalidateAge,
                        hasError: _ageError != null,
                      ),
                    ),
                    AccountField(
                      label: 'City',
                      errorText: _cityError,
                      child: _citiesLoading
                          ? const Text('Loading cities...')
                          : _citiesError
                          ? TextButton(
                              onPressed: () {
                                setState(() {
                                  _citiesLoading = true;
                                  _citiesError = false;
                                });
                                _loadCities();
                              },
                              child: const Text('Could not load cities. Retry'),
                            )
                          : CitySelector(
                              cities: _cities,
                              controller: _cityController,
                              selectedId: _cityId,
                              hasError: _cityError != null,
                              onSelected: (id) => setState(() {
                                _cityId = id;
                                _cityError = null;
                              }),
                            ),
                    ),
                    AccountField(
                      label: 'Password',
                      errorText: _passwordError,
                      child: DesignField(
                        controller: _passwordController,
                        obscureText: true,
                        autofillHints: const [AutofillHints.newPassword],
                        onChanged: _revalidatePassword,
                        hasError: _passwordError != null,
                      ),
                    ),
                    AccountField(
                      label: 'Preferred Category',
                      isLast: true,
                      errorText: _categoryError,
                      child: DesignDropdown(
                        value: _category,
                        items: CategoryCatalog.labelsById.values.toList(),
                        hasError: _categoryError != null,
                        onChanged: (value) => setState(() {
                          _category = value;
                          _categoryError = null;
                        }),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 15),
              PillButton(
                label: _isLoading ? 'Creating...' : 'Create an account',
                onPressed: _isLoading ? () {} : _createAccount,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

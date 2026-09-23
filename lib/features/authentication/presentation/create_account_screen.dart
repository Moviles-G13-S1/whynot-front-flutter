import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../app/app_routes.dart';
import '../../../app/dependencies_scope.dart';
import '../../../app/whynot_theme.dart';
import '../../../shared/domain/category_catalog.dart';
import '../../../shared/domain/city.dart';
import '../../../shared/widgets/brand_mark.dart';
import '../../../shared/widgets/city_selector.dart';
import '../../../shared/widgets/form_controls.dart';
import '../../profile/domain/user_profile.dart';
import 'widgets/account_field.dart';
import '../domain/auth_repository.dart';

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
      final cities = await context.dependencies.cityRepository.getCities();
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

    if (name.isEmpty ||
        email.isEmpty ||
        password.isEmpty ||
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

    setState(() => _isLoading = true);

    try {
      await context.dependencies.authController.createAccount(
        name: name,
        email: email,
        password: password,
        gender: _gender!,
        age: age,
        preferredCategoryId: CategoryCatalog.idsByLabel[_category]!,
        cityId: selectedCity.id,
      );

      if (!mounted) return;

      Navigator.pushNamedAndRemoveUntil(context, AppRoutes.home, (_) => false);
    } on AuthFailure catch (error) {
      if (!mounted) return;

      switch (error.code) {
        case 'invalid-name':
          _showMessage(
            'Name must have at most '
            '${UserProfileConstraints.maximumNameLength} characters.',
          );
          break;
        case 'invalid-age':
          _showMessage(
            'Age must be between ${UserProfileConstraints.minimumAge} and '
            '${UserProfileConstraints.maximumAge}.',
          );
          break;
        case 'weak-password':
          _showMessage('The password is too weak.');
          break;
        case 'email-already-in-use':
          _showMessage('An account already exists with this email.');
          break;
        case 'invalid-email':
          _showMessage('Please enter a valid email.');
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
                      child: DesignField(
                        controller: _nameController,
                        autofillHints: const [AutofillHints.name],
                        inputFormatters: [
                          LengthLimitingTextInputFormatter(
                            UserProfileConstraints.maximumNameLength,
                          ),
                        ],
                      ),
                    ),
                    AccountField(
                      label: 'Email',
                      child: DesignField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        autofillHints: const [AutofillHints.email],
                      ),
                    ),
                    AccountField(
                      label: 'Gender',
                      child: DesignDropdown(
                        value: _gender,
                        items: const ['Female', 'Male', 'Other'],
                        onChanged: (value) => setState(() => _gender = value),
                      ),
                    ),
                    AccountField(
                      label: 'Age',
                      child: DesignField(
                        controller: _ageController,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                      ),
                    ),
                    AccountField(
                      label: 'City',
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
                              onSelected: (id) => setState(() => _cityId = id),
                            ),
                    ),
                    AccountField(
                      label: 'Password',
                      child: DesignField(
                        controller: _passwordController,
                        obscureText: true,
                        autofillHints: const [AutofillHints.newPassword],
                      ),
                    ),
                    AccountField(
                      label: 'Preferred Category',
                      isLast: true,
                      child: DesignDropdown(
                        value: _category,
                        items: CategoryCatalog.labelsById.values.toList(),
                        onChanged: (value) => setState(() => _category = value),
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

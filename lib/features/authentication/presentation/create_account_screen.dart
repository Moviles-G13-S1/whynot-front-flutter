import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../app/app_routes.dart';
import '../../../app/whynot_theme.dart';
import '../../../shared/widgets/brand_mark.dart';
import '../../../shared/widgets/form_controls.dart';
import 'widgets/account_field.dart';

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
  final _passwordController = TextEditingController();

  String? _gender;
  String? _category;
  bool _isLoading = false;

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

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _ageController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _createAccount() async {
    FocusScope.of(context).unfocus();

    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final age = int.tryParse(_ageController.text.trim());

    if (name.isEmpty ||
        email.isEmpty ||
        password.isEmpty ||
        age == null ||
        _gender == null ||
        _category == null) {
      _showMessage('Please complete all fields.');
      return;
    }

    setState(() => _isLoading = true);

    try {
      // 1. Create the account in Firebase Authentication.
      final credential =
          await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final user = credential.user;

      if (user == null) {
        throw Exception('User could not be created.');
      }

      // 2. Save the rest of the user profile in Firestore.
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'name': name,
        'email': email,
        'gender': _gender,
        'age': age,
        'preferredCategoryId': _categoryIds[_category],
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;

      Navigator.pushNamedAndRemoveUntil(
        context,
        AppRoutes.home,
        (_) => false,
      );
    } on FirebaseAuthException catch (error) {
      if (!mounted) return;

      switch (error.code) {
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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
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
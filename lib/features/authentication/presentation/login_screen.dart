import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../app/app_routes.dart';
import '../../../app/whynot_theme.dart';
import '../../admin/application/admin_access.dart';
import '../../../shared/widgets/brand_mark.dart';
import '../../../shared/widgets/form_controls.dart';

/// Entry screen for returning users.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  /// Authenticates the user with Firebase Authentication.
  Future<void> _login() async {
    FocusScope.of(context).unfocus();

    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      _showMessage('Please enter your email and password.');
      return;
    }

    setState(() => _isLoading = true);

    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      final access = await AdminAuthorization.resolve();

      if (!mounted) return;

      Navigator.pushNamedAndRemoveUntil(
        context,
        access == AdminAccess.admin
            ? AppRoutes.adminDashboard
            : AppRoutes.home,
        (route) => false,
      );
    } on FirebaseAuthException catch (error) {
      if (!mounted) return;

      switch (error.code) {
        case 'invalid-email':
          _showMessage('Please enter a valid email.');
          break;

        case 'user-not-found':
        case 'wrong-password':
        case 'invalid-credential':
          _showMessage('Incorrect email or password.');
          break;

        case 'user-disabled':
          _showMessage('This account has been disabled.');
          break;

        default:
          _showMessage('Could not log in. Please try again.');
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
    final topSpace = (180 - safeTop).clamp(100.0, 180.0).toDouble();

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(height: topSpace),
              const Center(child: BrandMark()),
              const SizedBox(height: 43),
              Center(
                child: Text(
                  'Log in',
                  style: WhyNotTextStyles.muted(size: 15),
                ),
              ),
              const SizedBox(height: 20),
              FormSurface(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const FieldLabel('Email'),
                    const SizedBox(height: 7),
                    DesignField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      autofillHints: const [AutofillHints.email],
                    ),
                    const SizedBox(height: 31),
                    const FieldLabel('Password'),
                    const SizedBox(height: 7),
                    DesignField(
                      controller: _passwordController,
                      obscureText: true,
                      autofillHints: const [AutofillHints.password],
                      onSubmitted: (_) => _login(),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),
              PillButton(
                label: _isLoading ? 'Logging in...' : 'Log in',
                onPressed: _isLoading ? () {} : _login,
              ),
              const SizedBox(height: 23),
              const Divider(
                color: Color(0xFFC9C3BE),
                height: 1,
              ),
              const SizedBox(height: 19),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: () =>
                      Navigator.pushNamed(context, AppRoutes.createAccount),
                  style: linkButtonStyle(),
                  child: const Text('Create an account'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

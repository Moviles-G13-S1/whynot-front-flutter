import 'package:flutter/material.dart';

import '../../app/app_routes.dart';
import '../../app/dependencies_scope.dart';
import '../../app/whynot_theme.dart';
import '../../controllers/admin_access_controller.dart';
import '../../models/input_policy.dart';
import '../../models/repositories/auth_repository.dart';
import '../widgets/brand_mark.dart';
import '../widgets/form_controls.dart';
import '../widgets/offline_notice.dart';

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
  String? _emailError;
  String? _passwordError;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  /// Sends the login intent through the authentication controller.
  Future<void> _login() async {
    if (_isLoading) return;
    FocusScope.of(context).unfocus();

    final email = _emailController.text.trim();
    final password = _passwordController.text;

    final emailError = InputPolicy.emailValidationError(email);
    final passwordError = InputPolicy.passwordValidationError(password);
    setState(() {
      _emailError = emailError;
      _passwordError = passwordError;
    });
    if (emailError != null || passwordError != null) return;

    setState(() => _isLoading = true);

    try {
      final dependencies = context.dependencies;
      await dependencies.authController.signIn(
        email: email,
        password: password,
      );

      final access = await dependencies.adminAccessController.resolve();

      if (!mounted) return;

      Navigator.pushNamedAndRemoveUntil(
        context,
        access == AdminAccess.admin ? AppRoutes.adminDashboard : AppRoutes.home,
        (route) => false,
      );
    } on AuthFailure catch (error) {
      if (!mounted) return;

      switch (error.code) {
        case 'network-request-failed':
          _showMessage(
            'Login needs an internet connection. Your inputs are still here. Reconnect and try again.',
          );
          break;
        case 'invalid-email':
          setState(() => _emailError = 'Enter a valid email address.');
          break;

        case 'user-not-found':
        case 'wrong-password':
        case 'invalid-credential':
          setState(() => _passwordError = 'Incorrect email or password.');
          break;

        case 'user-disabled':
          setState(() => _emailError = 'This account has been disabled.');
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
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void _revalidateEmail(String value) {
    if (_emailError == null) return;
    setState(() => _emailError = InputPolicy.emailValidationError(value));
  }

  void _revalidatePassword(String value) {
    if (_passwordError == null) return;
    setState(() => _passwordError = InputPolicy.passwordValidationError(value));
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
                child: Text('Log in', style: WhyNotTextStyles.muted(size: 15)),
              ),
              const SizedBox(height: 20),
              const OfflineNotice(
                compact: true,
                message: 'Reconnect to log in. Your inputs will stay here.',
              ),
              FormSurface(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    FieldLabel('Email', hasError: _emailError != null),
                    const SizedBox(height: 7),
                    DesignField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      autofillHints: const [AutofillHints.email],
                      errorText: _emailError,
                      onChanged: _revalidateEmail,
                    ),
                    const SizedBox(height: 31),
                    FieldLabel('Password', hasError: _passwordError != null),
                    const SizedBox(height: 7),
                    DesignField(
                      controller: _passwordController,
                      obscureText: true,
                      autofillHints: const [AutofillHints.password],
                      onSubmitted: (_) => _login(),
                      errorText: _passwordError,
                      onChanged: _revalidatePassword,
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
              const Divider(color: Color(0xFFC9C3BE), height: 1),
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

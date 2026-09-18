import 'package:flutter/material.dart';

import '../../../app/app_routes.dart';
import '../../../app/whynot_theme.dart';
import '../../../shared/widgets/brand_mark.dart';
import '../../../shared/widgets/form_controls.dart';

/// Entry screen for returning users.
///
/// Authentication is intentionally simulated until a backend contract exists.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  /// Closes the keyboard and replaces authentication with the home screen.
  void _login() {
    FocusScope.of(context).unfocus();
    Navigator.pushReplacementNamed(context, AppRoutes.home);
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
              PillButton(label: 'Log in', onPressed: _login),
              const SizedBox(height: 37),
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

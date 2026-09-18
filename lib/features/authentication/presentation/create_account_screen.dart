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

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _ageController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  /// Completes the prototype flow without leaving authentication in history.
  void _createAccount() {
    FocusScope.of(context).unfocus();
    Navigator.pushNamedAndRemoveUntil(context, AppRoutes.home, (_) => false);
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
                        items: const ['Beauty', 'Clothes', 'Tech'],
                        onChanged: (value) => setState(() => _category = value),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 15),
              PillButton(label: 'Create an account', onPressed: _createAccount),
            ],
          ),
        ),
      ),
    );
  }
}

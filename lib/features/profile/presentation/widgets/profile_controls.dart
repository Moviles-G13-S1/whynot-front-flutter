import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../app/whynot_theme.dart';
import '../../../../shared/widgets/form_controls.dart';

/// Avatar exported from the profile frame in Figma.
class ProfileAvatar extends StatelessWidget {
  const ProfileAvatar({this.size = 100, super.key});

  final double size;

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset(
      'assets/figma/profile_avatar.svg',
      width: size,
      height: size,
    );
  }
}

/// Read-only label and value displayed on the profile card.
class ProfileValue extends StatelessWidget {
  const ProfileValue({
    required this.label,
    required this.value,
    this.isLast = false,
    this.onTap,
    super.key,
  });

  final String label;
  final String value;
  final bool isLast;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: EdgeInsets.only(bottom: isLast ? 0 : 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FieldLabel(label),
            const SizedBox(height: 9),
            Text(value, style: WhyNotTextStyles.muted(size: 15)),
          ],
        ),
      ),
    );
  }
}

/// Password input paired with the spacing used on the password screen.
class PasswordFieldGroup extends StatelessWidget {
  const PasswordFieldGroup({
    required this.label,
    required this.hint,
    required this.controller,
    this.isLast = false,
    super.key,
  });

  final String label;
  final String hint;
  final TextEditingController controller;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 27),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 7),
            child: FieldLabel(label),
          ),
          const SizedBox(height: 9),
          DesignField(controller: controller, hint: hint, obscureText: true),
        ],
      ),
    );
  }
}

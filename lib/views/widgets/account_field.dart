import 'package:flutter/material.dart';

import 'form_controls.dart';

/// A labeled field with the vertical spacing used by account forms.
class AccountField extends StatelessWidget {
  const AccountField({
    required this.label,
    required this.child,
    this.isLast = false,
    this.errorText,
    super.key,
  });

  final String label;
  final Widget child;
  final bool isLast;
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 31),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 7),
            child: FieldLabel(label, hasError: errorText != null),
          ),
          const SizedBox(height: 7),
          child,
          if (errorText != null) ...[
            const SizedBox(height: 5),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 7),
              child: FieldErrorMessage(errorText!),
            ),
          ],
        ],
      ),
    );
  }
}

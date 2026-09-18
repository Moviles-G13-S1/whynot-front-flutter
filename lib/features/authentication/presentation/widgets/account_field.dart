import 'package:flutter/material.dart';

import '../../../../shared/widgets/form_controls.dart';

/// A labeled field with the vertical spacing used by account forms.
class AccountField extends StatelessWidget {
  const AccountField({
    required this.label,
    required this.child,
    this.isLast = false,
    super.key,
  });

  final String label;
  final Widget child;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 31),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 7),
            child: FieldLabel(label),
          ),
          const SizedBox(height: 7),
          child,
        ],
      ),
    );
  }
}

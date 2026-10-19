import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/whynot_theme.dart';

/// Rounded background that groups related fields.
class FormSurface extends StatelessWidget {
  const FormSurface({
    required this.child,
    this.padding = const EdgeInsets.fromLTRB(11, 11, 11, 43),
    super.key,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: WhyNotColors.form,
        borderRadius: BorderRadius.circular(20),
      ),
      child: child,
    );
  }
}

/// Label shared by account and profile fields.
class FieldLabel extends StatelessWidget {
  const FieldLabel(this.label, {super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(label, style: WhyNotTextStyles.serif(size: 20));
  }
}

/// Text field styled according to the design system.
class DesignField extends StatelessWidget {
  const DesignField({
    required this.controller,
    this.hint,
    this.keyboardType,
    this.obscureText = false,
    this.autofillHints,
    this.onSubmitted,
    this.inputFormatters,
    super.key,
  });

  final TextEditingController controller;
  final String? hint;
  final TextInputType? keyboardType;
  final bool obscureText;
  final Iterable<String>? autofillHints;
  final ValueChanged<String>? onSubmitted;
  final List<TextInputFormatter>? inputFormatters;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 36,
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        obscureText: obscureText,
        autofillHints: autofillHints,
        onSubmitted: onSubmitted,
        inputFormatters: inputFormatters,
        style: const TextStyle(
          fontFamily: 'Poppins',
          fontSize: 14,
          fontWeight: FontWeight.w300,
        ),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: WhyNotTextStyles.muted(size: 14),
          filled: true,
          fillColor: WhyNotColors.field,
          contentPadding: const EdgeInsets.symmetric(horizontal: 13),
          enabledBorder: fieldBorder(),
          focusedBorder: fieldBorder(color: WhyNotColors.muted),
        ),
      ),
    );
  }
}

/// Dropdown that shares dimensions and decoration with [DesignField].
class DesignDropdown extends StatelessWidget {
  const DesignDropdown({
    required this.value,
    required this.items,
    required this.onChanged,
    super.key,
  });

  final String? value;
  final List<String> items;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 36,
      child: DropdownButtonFormField<String>(
        initialValue: value,
        onChanged: onChanged,
        icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 18),
        style: const TextStyle(
          color: WhyNotColors.muted,
          fontFamily: 'Poppins',
          fontSize: 14,
          fontWeight: FontWeight.w300,
        ),
        decoration: InputDecoration(
          filled: true,
          fillColor: WhyNotColors.field,
          contentPadding: const EdgeInsets.symmetric(horizontal: 13),
          enabledBorder: fieldBorder(),
          focusedBorder: fieldBorder(color: WhyNotColors.muted),
        ),
        items: items
            .map((item) => DropdownMenuItem(value: item, child: Text(item)))
            .toList(),
      ),
    );
  }
}

/// Primary pill-shaped action used by forms.
class PillButton extends StatelessWidget {
  const PillButton({
    required this.label,
    required this.onPressed,
    this.height = 38,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          elevation: 4,
          shadowColor: const Color(0x66000000),
          backgroundColor: WhyNotColors.field,
          disabledBackgroundColor: WhyNotColors.field,
          foregroundColor: WhyNotColors.muted,
          disabledForegroundColor: WhyNotColors.muted,
          shape: RoundedRectangleBorder(
            side: const BorderSide(color: WhyNotColors.border),
            borderRadius: BorderRadius.circular(24),
          ),
          textStyle: const TextStyle(
            fontFamily: 'Poppins',
            fontSize: 15,
            fontWeight: FontWeight.w300,
          ),
        ),
        child: Text(label),
      ),
    );
  }
}

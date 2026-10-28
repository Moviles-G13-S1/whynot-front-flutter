import 'package:flutter/foundation.dart';
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
  const FieldLabel(this.label, {this.hasError = false, super.key});

  final String label;
  final bool hasError;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: WhyNotTextStyles.serif(
        size: 20,
        color: hasError ? WhyNotColors.error : Colors.black,
      ),
    );
  }
}

/// Compact, accessible feedback displayed immediately below an invalid field.
class FieldErrorMessage extends StatelessWidget {
  const FieldErrorMessage(this.message, {super.key});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.error_outline_rounded,
            size: 14,
            color: WhyNotColors.error,
          ),
          const SizedBox(width: 5),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: WhyNotColors.error,
                fontFamily: 'Poppins',
                fontSize: 11,
                height: 1.25,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Text field styled according to the design system.
class DesignField extends StatefulWidget {
  const DesignField({
    required this.controller,
    this.hint,
    this.keyboardType,
    this.obscureText = false,
    this.autofillHints,
    this.onSubmitted,
    this.inputFormatters,
    this.errorText,
    this.onChanged,
    this.hasError = false,
    super.key,
  });

  final TextEditingController controller;
  final String? hint;
  final TextInputType? keyboardType;
  final bool obscureText;
  final Iterable<String>? autofillHints;
  final ValueChanged<String>? onSubmitted;
  final List<TextInputFormatter>? inputFormatters;
  final String? errorText;
  final ValueChanged<String>? onChanged;
  final bool hasError;

  @override
  State<DesignField> createState() => _DesignFieldState();
}

class _DesignFieldState extends State<DesignField> {
  bool _revealingPassword = false;

  bool _usesTapToReveal(BuildContext context) =>
      !kIsWeb &&
      (Theme.of(context).platform == TargetPlatform.android ||
          Theme.of(context).platform == TargetPlatform.iOS);

  void _setPasswordVisibility(bool visible) {
    if (!widget.obscureText || _revealingPassword == visible) return;
    setState(() => _revealingPassword = visible);
  }

  Widget? _suffixIcon(BuildContext context, bool invalid) {
    if (widget.obscureText) {
      final mobileInteraction = _usesTapToReveal(context);
      final interactionLabel = mobileInteraction
          ? _revealingPassword
                ? 'Tap to hide password'
                : 'Tap to show password'
          : _revealingPassword
          ? 'Release to hide password'
          : 'Press and hold to show password';
      final eye = Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: Icon(
          _revealingPassword
              ? Icons.visibility_off_outlined
              : Icons.visibility_outlined,
          color: invalid ? WhyNotColors.error : WhyNotColors.muted,
          size: 19,
        ),
      );
      return Tooltip(
        message: interactionLabel,
        child: Semantics(
          button: true,
          label: interactionLabel,
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            child: mobileInteraction
                ? GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => _setPasswordVisibility(!_revealingPassword),
                    child: eye,
                  )
                : Listener(
                    behavior: HitTestBehavior.opaque,
                    onPointerDown: (_) => _setPasswordVisibility(true),
                    onPointerUp: (_) => _setPasswordVisibility(false),
                    onPointerCancel: (_) => _setPasswordVisibility(false),
                    child: eye,
                  ),
          ),
        ),
      );
    }
    if (invalid) {
      return const Icon(
        Icons.error_outline_rounded,
        color: WhyNotColors.error,
        size: 18,
      );
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final invalid = widget.hasError || widget.errorText != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 36,
          child: TextField(
            controller: widget.controller,
            keyboardType: widget.keyboardType,
            obscureText: widget.obscureText && !_revealingPassword,
            autofillHints: widget.autofillHints,
            onSubmitted: widget.onSubmitted,
            onChanged: widget.onChanged,
            inputFormatters: widget.inputFormatters,
            cursorColor: invalid ? WhyNotColors.error : null,
            style: const TextStyle(
              fontFamily: 'Poppins',
              fontSize: 14,
              fontWeight: FontWeight.w300,
            ),
            decoration: InputDecoration(
              hintText: widget.hint,
              hintStyle: WhyNotTextStyles.muted(size: 14),
              filled: true,
              fillColor: invalid
                  ? WhyNotColors.errorSurface
                  : WhyNotColors.field,
              contentPadding: const EdgeInsets.symmetric(horizontal: 13),
              suffixIcon: _suffixIcon(context, invalid),
              suffixIconConstraints: const BoxConstraints(
                minWidth: 38,
                minHeight: 36,
              ),
              enabledBorder: fieldBorder(
                color: invalid ? WhyNotColors.error : WhyNotColors.border,
                width: invalid ? 1.5 : 1,
              ),
              focusedBorder: fieldBorder(
                color: invalid ? WhyNotColors.error : WhyNotColors.muted,
                width: invalid ? 1.8 : 1,
              ),
            ),
          ),
        ),
        if (widget.errorText != null) ...[
          const SizedBox(height: 5),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 7),
            child: FieldErrorMessage(widget.errorText!),
          ),
        ],
      ],
    );
  }
}

/// Dropdown that shares dimensions and decoration with [DesignField].
class DesignDropdown extends StatelessWidget {
  const DesignDropdown({
    required this.value,
    required this.items,
    required this.onChanged,
    this.hasError = false,
    super.key,
  });

  final String? value;
  final List<String> items;
  final ValueChanged<String?> onChanged;
  final bool hasError;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 36,
      child: DropdownButtonFormField<String>(
        isExpanded: true,
        initialValue: value,
        onChanged: onChanged,
        icon: Icon(
          hasError
              ? Icons.error_outline_rounded
              : Icons.keyboard_arrow_down_rounded,
          size: 18,
          color: hasError ? WhyNotColors.error : null,
        ),
        style: const TextStyle(
          color: WhyNotColors.muted,
          fontFamily: 'Poppins',
          fontSize: 14,
          fontWeight: FontWeight.w300,
        ),
        decoration: InputDecoration(
          filled: true,
          fillColor: hasError ? WhyNotColors.errorSurface : WhyNotColors.field,
          contentPadding: const EdgeInsets.symmetric(horizontal: 13),
          enabledBorder: fieldBorder(
            color: hasError ? WhyNotColors.error : WhyNotColors.border,
            width: hasError ? 1.5 : 1,
          ),
          focusedBorder: fieldBorder(
            color: hasError ? WhyNotColors.error : WhyNotColors.muted,
            width: hasError ? 1.8 : 1,
          ),
        ),
        items: items
            .map(
              (item) => DropdownMenuItem(
                value: item,
                child: Text(item, maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
            )
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

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../app/whynot_theme.dart';
import 'form_controls.dart';

/// Profile photo with the original Figma avatar as a fallback.
class ProfileAvatar extends StatefulWidget {
  const ProfileAvatar({
    this.size = 100,
    this.photoPath,
    this.loadPhoto,
    this.preview,
    super.key,
  });

  final double size;
  final String? photoPath;
  final Future<Uint8List?> Function(String path)? loadPhoto;
  final Uint8List? preview;

  @override
  // Santiago Casasbuenas: Keep photo loading state with this avatar.
  State<ProfileAvatar> createState() => _ProfileAvatarState();
}

class _ProfileAvatarState extends State<ProfileAvatar> {
  Future<Uint8List?>? _photo;

  @override
  // Santiago Casasbuenas: Load the saved profile image on first display.
  void initState() {
    super.initState();
    _refreshPhoto();
  }

  @override
  // Santiago Casasbuenas: Refresh the image after a path change.
  void didUpdateWidget(ProfileAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.photoPath != widget.photoPath ||
        oldWidget.loadPhoto != widget.loadPhoto) {
      _refreshPhoto();
    }
  }

  // Santiago Casasbuenas: Resolve the owner-protected photo through the controller.
  void _refreshPhoto() {
    final path = widget.photoPath;
    _photo = path == null || widget.loadPhoto == null
        ? null
        : widget.loadPhoto!(path);
  }

  @override
  // Santiago Casasbuenas: Show the preview, stored image, or SVG fallback.
  Widget build(BuildContext context) {
    // Santiago Casasbuenas: Render the original avatar when no photo is available.
    Widget fallback() => SvgPicture.asset(
      'assets/figma/profile_avatar.svg',
      width: widget.size,
      height: widget.size,
    );
    // Santiago Casasbuenas: Crop chosen photo bytes into the profile avatar.
    Widget photo(Uint8List bytes) => ClipOval(
      child: Image.memory(
        bytes,
        width: widget.size,
        height: widget.size,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => fallback(),
      ),
    );
    if (widget.preview != null) return photo(widget.preview!);
    if (_photo == null) return fallback();
    return FutureBuilder<Uint8List?>(
      future: _photo,
      builder: (context, snapshot) {
        if (snapshot.hasData && snapshot.data != null) {
          return photo(snapshot.data!);
        }
        return fallback();
      },
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
    this.errorText,
    this.onChanged,
    super.key,
  });

  final String label;
  final String hint;
  final TextEditingController controller;
  final bool isLast;
  final String? errorText;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 27),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 7),
            child: FieldLabel(label, hasError: errorText != null),
          ),
          const SizedBox(height: 9),
          DesignField(
            controller: controller,
            hint: hint,
            obscureText: true,
            errorText: errorText,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter/foundation.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import '../../controllers/connectivity_status.dart';

import '../../app/whynot_theme.dart';
import 'form_controls.dart';

/// Profile photo with the original Figma avatar as a fallback.
class ProfileAvatar extends StatefulWidget {
  const ProfileAvatar({
    this.size = 100,
    this.photoPath,
    this.loadPhotoUrl,
    this.preview,
    this.loadPhotoBytes,
    this.connectivity,
    this.cacheManager,
    super.key,
  });

  final double size;
  final String? photoPath;
  final Future<String> Function(String path)? loadPhotoUrl;
  final Uint8List? preview;
  final Future<Uint8List?> Function(String path)? loadPhotoBytes;
  final ConnectivityStatus? connectivity;
  final BaseCacheManager? cacheManager;

  @override
  // Santiago Casasbuenas: Keep photo loading state with this avatar.
  State<ProfileAvatar> createState() => _ProfileAvatarState();
}

class _ProfileAvatarState extends State<ProfileAvatar> {
  Future<({Uint8List? bytes, String? url})>? _photo;
  bool _wasOffline = false;

  @override
  // Santiago Casasbuenas: Load the saved profile image on first display.
  void initState() {
    super.initState();
    _wasOffline = widget.connectivity?.isOffline == true;
    widget.connectivity?.addListener(_connectionChanged);
    _refreshPhoto();
  }

  @override
  // Santiago Casasbuenas: Refresh the image after a path change.
  void didUpdateWidget(ProfileAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.connectivity != widget.connectivity) {
      oldWidget.connectivity?.removeListener(_connectionChanged);
      _wasOffline = widget.connectivity?.isOffline == true;
      widget.connectivity?.addListener(_connectionChanged);
    }
    if (oldWidget.photoPath != widget.photoPath ||
        oldWidget.loadPhotoUrl != widget.loadPhotoUrl ||
        oldWidget.loadPhotoBytes != widget.loadPhotoBytes) {
      _refreshPhoto();
    }
  }

  // Santiago Casasbuenas: Resolve the owner-protected photo through the controller.
  void _refreshPhoto() {
    final path = widget.photoPath;
    _photo = path == null ? null : _load(path);
  }

  Future<({Uint8List? bytes, String? url})> _load(String path) async {
    try {
      final bytes = await widget.loadPhotoBytes?.call(path);
      if (bytes != null) return (bytes: bytes, url: null);
    } catch (_) {
      /* Keep the existing online image fallback available. */
    }
    if (widget.connectivity?.isOffline == true) return (bytes: null, url: null);
    return (bytes: null, url: await widget.loadPhotoUrl?.call(path));
  }

  void _connectionChanged() {
    final offline = widget.connectivity?.isOffline == true;
    final recovered = _wasOffline && !offline;
    _wasOffline = offline;
    if (recovered && mounted) setState(_refreshPhoto);
  }

  @override
  void dispose() {
    widget.connectivity?.removeListener(_connectionChanged);
    super.dispose();
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
    Widget networkPhoto(String url) => ClipOval(
      child: !kIsWeb && widget.cacheManager != null
          ? CachedNetworkImage(
              imageUrl: url,
              cacheKey: widget.photoPath,
              cacheManager: widget.cacheManager,
              width: widget.size,
              height: widget.size,
              fit: BoxFit.cover,
              placeholder: (_, _) => fallback(),
              errorWidget: (_, _, _) => fallback(),
            )
          : Image.network(
              url,
              width: widget.size,
              height: widget.size,
              fit: BoxFit.cover,
              webHtmlElementStrategy: WebHtmlElementStrategy.prefer,
              errorBuilder: (_, _, _) => fallback(),
            ),
    );
    if (widget.preview != null) return photo(widget.preview!);
    if (_photo == null) return fallback();
    return FutureBuilder<({Uint8List? bytes, String? url})>(
      future: _photo,
      builder: (context, snapshot) {
        final result = snapshot.data;
        if (result?.bytes != null) return photo(result!.bytes!);
        if (result?.url?.isNotEmpty == true) return networkPhoto(result!.url!);
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

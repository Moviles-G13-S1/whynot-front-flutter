import 'package:flutter/material.dart';

import '../../app/whynot_theme.dart';
import 'form_controls.dart';

/// A calm, compact status that can sit above content kept on screen.
class ConnectivityNotice extends StatelessWidget {
  const ConnectivityNotice({
    required this.label,
    required this.title,
    required this.message,
    required this.icon,
    this.actionLabel,
    this.onAction,
    this.backgroundColor = WhyNotColors.form,
    super.key,
  });

  final String label;
  final String title;
  final String message;
  final IconData icon;
  final String? actionLabel;
  final VoidCallback? onAction;
  final Color backgroundColor;

  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    child: Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: WhyNotColors.divider),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: WhyNotColors.background,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 19, color: WhyNotColors.muted),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label.toUpperCase(),
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    color: WhyNotColors.muted,
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 1.1,
                  ),
                ),
                const SizedBox(height: 5),
                Text(title, style: WhyNotTextStyles.serif(size: 20)),
                const SizedBox(height: 7),
                Text(
                  message,
                  style: WhyNotTextStyles.muted(size: 12).copyWith(height: 1.4),
                ),
                if (actionLabel != null && onAction != null) ...[
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: onAction,
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.black87,
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(0, 32),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    icon: const Icon(Icons.arrow_forward_rounded, size: 16),
                    label: Text(actionLabel!),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

/// Full-page state for a catalog that has nothing safe to display.
class ConnectivityEmptyState extends StatelessWidget {
  const ConnectivityEmptyState({
    required this.label,
    required this.title,
    required this.message,
    required this.icon,
    this.actionLabel,
    this.onAction,
    super.key,
  });

  final String label;
  final String title;
  final String message;
  final IconData icon;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => Center(
    child: SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 40),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: Semantics(
          liveRegion: true,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: const BoxDecoration(
                  color: WhyNotColors.form,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 30, color: WhyNotColors.muted),
              ),
              const SizedBox(height: 24),
              Text(
                label.toUpperCase(),
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  color: WhyNotColors.muted,
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 9),
              Text(
                title,
                textAlign: TextAlign.center,
                style: WhyNotTextStyles.serif(size: 30),
              ),
              const SizedBox(height: 12),
              Text(
                message,
                textAlign: TextAlign.center,
                style: WhyNotTextStyles.muted(size: 13).copyWith(height: 1.45),
              ),
              if (actionLabel != null && onAction != null) ...[
                const SizedBox(height: 24),
                SizedBox(
                  width: 190,
                  child: PillButton(label: actionLabel!, onPressed: onAction),
                ),
              ],
            ],
          ),
        ),
      ),
    ),
  );
}

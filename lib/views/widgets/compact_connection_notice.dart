import 'package:flutter/material.dart';

import '../../app/whynot_theme.dart';

/// Compact status strip matching the Profile notice.
class CompactConnectionNotice extends StatelessWidget {
  const CompactConnectionNotice({
    required this.title,
    required this.message,
    required this.icon,
    this.actionLabel,
    this.onAction,
    super.key,
  });

  final String title;
  final String message;
  final IconData icon;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: Semantics(
      liveRegion: true,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: WhyNotColors.form,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 18, color: WhyNotColors.muted),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    message,
                    style: WhyNotTextStyles.muted(
                      size: 12,
                    ).copyWith(height: 1.4),
                  ),
                  if (actionLabel != null && onAction != null)
                    TextButton(onPressed: onAction, child: Text(actionLabel!)),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

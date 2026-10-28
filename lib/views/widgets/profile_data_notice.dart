import 'package:flutter/material.dart';

import '../../models/user_profile.dart';
import '../../app/whynot_theme.dart';

class ProfileDataNotice extends StatelessWidget {
  const ProfileDataNotice({
    required this.profile,
    this.failed = false,
    this.onRetry,
    this.offline = false,
    super.key,
  });
  final UserProfile? profile;
  final bool failed;
  final VoidCallback? onRetry;
  final bool offline;

  @override
  Widget build(BuildContext context) {
    final pending = profile?.hasPendingWrites == true;
    if (!pending && profile?.fromCache != true && !failed && !offline) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
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
            Icon(
              pending
                  ? Icons.cloud_upload_outlined
                  : offline
                  ? Icons.wifi_off_rounded
                  : Icons.history_rounded,
              size: 18,
              color: WhyNotColors.muted,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    pending
                        ? 'Profile changes are pending'
                        : 'Last available profile',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    pending
                        ? 'Your changes are still saving.'
                        : offline
                        ? 'Showing your saved profile while offline.'
                        : 'Updates resume when you reconnect to Wi-Fi or mobile data.',
                    style: WhyNotTextStyles.muted(
                      size: 12,
                    ).copyWith(height: 1.4),
                  ),
                  if (failed && onRetry != null)
                    TextButton(
                      onPressed: onRetry,
                      child: const Text('Retry profile'),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

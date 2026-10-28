import 'package:flutter/material.dart';

import '../../app/dependencies_scope.dart';
import 'connectivity_message.dart';
import 'compact_connection_notice.dart';

/// Transport status only: backend errors and pending writes have their own UI.
class OfflineNotice extends StatelessWidget {
  const OfflineNotice({required this.message, this.compact = false, super.key});
  final String message;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final connectivity = context.dependencies.connectivity;
    return AnimatedBuilder(
      animation: connectivity,
      builder: (context, _) => !connectivity.isOffline
          ? const SizedBox.shrink()
          : compact
          ? CompactConnectionNotice(
              title: 'You’re offline',
              message: message,
              icon: Icons.wifi_off_rounded,
            )
          : Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: ConnectivityNotice(
                label: 'Offline',
                title: 'No connection right now',
                message: message,
                icon: Icons.wifi_off_rounded,
                actionLabel: 'Check connection',
                onAction: connectivity.refresh,
              ),
            ),
    );
  }
}

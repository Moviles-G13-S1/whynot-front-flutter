import 'package:flutter/material.dart';
import '../../app/whynot_theme.dart';
import '../../controllers/monthly_spending_controller.dart';
import 'compact_connection_notice.dart';

String spendingMoney(int cents) {
  final whole = (cents ~/ 100).toString().replaceAllMapped(
    RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
    (match) => '${match[1]},',
  );
  return '\$$whole.${(cents % 100).toString().padLeft(2, '0')}';
}

String spendingMonthLabel(String month) {
  const names = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];
  return '${names[int.parse(month.substring(5)) - 1]} ${month.substring(0, 4)}';
}

class SpendingCard extends StatelessWidget {
  const SpendingCard({required this.child, super.key});
  final Widget child;
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    margin: const EdgeInsets.only(bottom: 16),
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: WhyNotColors.card,
      borderRadius: BorderRadius.circular(20),
    ),
    child: child,
  );
}

class SpendingStatus extends StatelessWidget {
  const SpendingStatus({required this.controller, super.key});
  final MonthlySpendingController controller;
  @override
  Widget build(BuildContext context) {
    final c = controller;
    if (c.offline || c.stale || c.failed || c.pendingWrites) {
      return CompactConnectionNotice(
        title: c.offline
            ? 'You are offline'
            : c.pendingWrites
            ? 'Changes pending'
            : 'Waiting for an update',
        message: c.hasData
            ? 'Showing your last synced purchases. Your totals will update when a server connection is available.'
            : 'Connect to load your spending summary. No synced purchases are available on this device yet.',
        icon: c.offline ? Icons.wifi_off_rounded : Icons.sync_rounded,
        actionLabel: c.offline ? null : 'Retry',
        onAction: c.offline ? null : c.refresh,
      );
    }
    if (c.storageFailed) {
      return const CompactConnectionNotice(
        title: 'Could not save offline copy',
        message:
            'Your online totals are available, but may not be available after restarting offline.',
        icon: Icons.storage_rounded,
      );
    }
    return const SizedBox.shrink();
  }
}

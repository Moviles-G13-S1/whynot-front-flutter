import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/app_routes.dart';
import '../../app/dependencies_scope.dart';
import '../../app/whynot_theme.dart';
import '../../controllers/recommendation_controller.dart';
import '../../models/recent_recommendation.dart';

/// Santiago Casasbuenas: Home loads local browsing history independently of
/// the online recommendations. Its heading stays visible for empty histories.
class RecentlyViewedSection extends StatefulWidget {
  const RecentlyViewedSection({super.key});

  @override
  State<RecentlyViewedSection> createState() => _RecentlyViewedSectionState();
}

class _RecentlyViewedSectionState extends State<RecentlyViewedSection> {
  RecommendationController? _controller;
  StreamSubscription<void>? _historySubscription;
  Future<List<RecentRecommendation>>? _history;
  String? _historyUserId;
  bool _opening = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final controller = context.dependencies.recommendationController;
    if (_controller == controller) return;
    _historySubscription?.cancel();
    _controller = controller;
    _readHistory();
    _historySubscription = controller.historyChanges.listen((_) {
      if (mounted) setState(_readHistory);
    });
  }

  void _readHistory() {
    final controller = _controller!;
    _historyUserId = controller.currentUserId;
    _history = controller.readRecentRecommendations();
  }

  @override
  void dispose() {
    _historySubscription?.cancel();
    super.dispose();
  }

  Future<void> _open(String sourceProductId) async {
    final controller = _controller!;
    if (_opening || _historyUserId != controller.currentUserId) return;
    setState(() => _opening = true);
    try {
      final opening = await controller.beginRecentOpen(sourceProductId);
      if (!mounted || !controller.isCurrentCatalogOpen(opening)) return;
      await Navigator.pushNamed(
        context,
        AppRoutes.recommendationDetail,
        arguments: opening,
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This history entry is unavailable.')),
      );
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  Future<void> _clearHistory() async {
    final controller = _controller!;
    final userId = controller.currentUserId;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear recently viewed?'),
        content: const Text(
          'This will remove your recommendation history from this device.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Clear history'),
          ),
        ],
      ),
    );
    if (!mounted || confirmed != true || userId != controller.currentUserId) {
      return;
    }
    try {
      await controller.clearRecentRecommendations();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Couldn’t clear your history. Try again.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) =>
      FutureBuilder<List<RecentRecommendation>>(
        future: _history,
        builder: (context, snapshot) {
          final userId = _controller?.currentUserId;
          final historyReady =
              _historyUserId == userId &&
              snapshot.connectionState == ConnectionState.done;
          final entries = userId != null && historyReady
              ? snapshot.data ?? const <RecentRecommendation>[]
              : const <RecentRecommendation>[];
          final status = userId == null
              ? 'Sign in to see your history.'
              : !historyReady
              ? 'Loading history…'
              : snapshot.hasError
              ? 'Recently viewed is unavailable right now.'
              : 'No recently viewed recommendations yet.';
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Recently viewed',
                      style: WhyNotTextStyles.serif(size: 23),
                    ),
                  ),
                  if (entries.isNotEmpty)
                    TextButton(
                      onPressed: _opening ? null : _clearHistory,
                      child: const Text('Clear history'),
                    ),
                ],
              ),
              if (entries.isEmpty) ...[
                const SizedBox(height: 8),
                Text(status, style: WhyNotTextStyles.muted(size: 12)),
              ] else ...[
                Text(
                  'Saved on this device. Details may be outdated.',
                  style: WhyNotTextStyles.muted(size: 12),
                ),
                const SizedBox(height: 8),
                Material(
                  color: WhyNotColors.card,
                  borderRadius: BorderRadius.circular(16),
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    children: [
                      for (final entry in entries)
                        ListTile(
                          key: ValueKey('recent-${entry.sourceProductId}'),
                          leading: const Icon(Icons.history_rounded),
                          title: Text(entry.details.name),
                          subtitle: entry.details.brand.isEmpty
                              ? null
                              : Text(entry.details.brand),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: _opening
                              ? null
                              : () => _open(entry.sourceProductId),
                        ),
                    ],
                  ),
                ),
              ],
            ],
          );
        },
      );
}

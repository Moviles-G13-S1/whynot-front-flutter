import 'dart:async';
import 'package:flutter/material.dart';
import '../../app/app_routes.dart';
import '../../app/dependencies_scope.dart';
import '../../app/whynot_theme.dart';
import '../../controllers/monthly_spending_controller.dart';
import '../../models/monthly_spending.dart';
import '../widgets/spending_components.dart';
import 'category_spending_detail_screen.dart';

class MonthlySpendingScreen extends StatefulWidget {
  const MonthlySpendingScreen({this.controller, super.key});
  final MonthlySpendingController? controller;
  @override
  State<MonthlySpendingScreen> createState() => _MonthlySpendingScreenState();
}

class _MonthlySpendingScreenState extends State<MonthlySpendingScreen> {
  MonthlySpendingController? _controller;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_controller != null) return;
    _controller =
        widget.controller ??
        context.dependencies.createMonthlySpendingController();
    unawaited(_controller!.start());
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = _controller!;
    return Scaffold(
      backgroundColor: WhyNotColors.background,
      appBar: AppBar(
        title: const Text('Monthly Spending'),
        backgroundColor: WhyNotColors.background,
        actions: [
          AnimatedBuilder(
            animation: c,
            builder: (context, _) => IconButton(
              tooltip: 'Refresh spending',
              onPressed: c.offline ? null : c.refresh,
              icon: const Icon(Icons.refresh_rounded),
            ),
          ),
        ],
      ),
      body: AnimatedBuilder(
        animation: c,
        builder: (context, _) {
          final summary = c.summary;
          return RefreshIndicator(
            onRefresh: c.refresh,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
              children: [
                Text(
                  'Your month, in perspective',
                  style: WhyNotTextStyles.serif(size: 28),
                ),
                const SizedBox(height: 8),
                Text(
                  'Explore your purchases and where your spending goes.',
                  style: WhyNotTextStyles.muted(size: 13),
                ),
                const SizedBox(height: 24),
                SpendingStatus(controller: c),
                DropdownButtonFormField<String>(
                  initialValue: c.selectedMonth,
                  decoration: const InputDecoration(
                    labelText: 'Month',
                    border: OutlineInputBorder(),
                  ),
                  isExpanded: true,
                  items: c.months
                      .map(
                        (month) => DropdownMenuItem(
                          value: month,
                          child: Text(spendingMonthLabel(month)),
                        ),
                      )
                      .toList(),
                  onChanged: (month) {
                    if (month != null) unawaited(c.selectMonth(month));
                  },
                ),
                const SizedBox(height: 20),
                if (c.loading || c.calculating)
                  const Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (!c.hasData || summary == null)
                  SpendingCard(
                    child: Column(
                      children: [
                        const Icon(Icons.receipt_long_outlined, size: 36),
                        const SizedBox(height: 12),
                        Text(
                          'Your summary is not available yet',
                          textAlign: TextAlign.center,
                          style: WhyNotTextStyles.serif(size: 22),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Connect and retry to load your purchases.',
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  )
                else ...[
                  SpendingCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'TOTAL SPENT',
                          style: WhyNotTextStyles.muted(size: 11),
                        ),
                        const SizedBox(height: 8),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            spendingMoney(summary.totalCents),
                            style: WhyNotTextStyles.serif(size: 38),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${summary.count} purchased ${summary.count == 1 ? 'product' : 'products'} · ${spendingMonthLabel(summary.month)}',
                          style: WhyNotTextStyles.muted(size: 12),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    'Spending by category',
                    style: WhyNotTextStyles.serif(size: 24),
                  ),
                  const SizedBox(height: 12),
                  if (summary.categories.isEmpty)
                    SpendingCard(
                      child: Column(
                        children: [
                          const Icon(Icons.shopping_bag_outlined, size: 32),
                          const SizedBox(height: 12),
                          Text(
                            'No purchases this month',
                            style: WhyNotTextStyles.serif(size: 21),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Choose another month to explore your spending.',
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  for (final category in summary.categories)
                    _categoryTile(c, summary, category),
                  if (c.undatedCount > 0)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Text(
                        '${c.undatedCount} purchased products have no purchase date and are excluded from monthly totals.',
                        style: WhyNotTextStyles.muted(size: 12),
                      ),
                    ),
                ],
                if (c.syncedAt != null)
                  Text(
                    'Last synced: ${MaterialLocalizations.of(context).formatShortDate(c.syncedAt!.toLocal())} ${TimeOfDay.fromDateTime(c.syncedAt!.toLocal()).format(context)}',
                    style: WhyNotTextStyles.muted(size: 11),
                  ),
                const SizedBox(height: 8),
                Text(
                  'Based on the recorded prices of your current purchased products. Months use Colombia time. Deleted products no longer count.',
                  style: WhyNotTextStyles.muted(size: 11),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _categoryTile(
    MonthlySpendingController c,
    MonthlySpending summary,
    SpendingCategory category,
  ) {
    final share = summary.totalCents == 0
        ? 0.0
        : category.totalCents / summary.totalCents;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: WhyNotColors.form,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => Navigator.pushNamed(
            context,
            AppRoutes.categorySpendingDetail,
            arguments: CategorySpendingArguments(
              controller: c,
              month: summary.month,
              categoryId: category.id,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        spendingCategoryName(category.id),
                        style: WhyNotTextStyles.serif(size: 21),
                      ),
                    ),
                    Text(spendingMoney(category.totalCents)),
                    const Icon(Icons.chevron_right_rounded, size: 20),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '${category.products.length} products · ${(share * 100).toStringAsFixed(1)}% of this month',
                  style: WhyNotTextStyles.muted(size: 11),
                ),
                const SizedBox(height: 12),
                LinearProgressIndicator(
                  value: share,
                  minHeight: 5,
                  borderRadius: BorderRadius.circular(4),
                  color: Colors.black87,
                  backgroundColor: WhyNotColors.divider,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

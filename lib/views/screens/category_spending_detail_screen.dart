import 'package:flutter/material.dart';
import '../../app/whynot_theme.dart';
import '../../controllers/monthly_spending_controller.dart';
import '../../models/monthly_spending.dart';
import '../widgets/spending_components.dart';

class CategorySpendingArguments {
  const CategorySpendingArguments({
    required this.controller,
    required this.month,
    required this.categoryId,
  });
  final MonthlySpendingController controller;
  final String month;
  final String categoryId;
}

class CategorySpendingDetailScreen extends StatelessWidget {
  const CategorySpendingDetailScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is! CategorySpendingArguments) {
      return Scaffold(
        appBar: AppBar(title: const Text('Category Spending Detail')),
        body: const Center(
          child: Text('Choose a category from Monthly Spending.'),
        ),
      );
    }
    final c = args.controller;
    return Scaffold(
      backgroundColor: WhyNotColors.background,
      appBar: AppBar(
        title: const Text('Category Spending Detail'),
        backgroundColor: WhyNotColors.background,
      ),
      body: AnimatedBuilder(
        animation: c,
        builder: (context, _) {
          final summary = c.summary;
          SpendingCategory? category;
          if (summary?.month == args.month) {
            for (final row in summary!.categories) {
              if (row.id == args.categoryId) category = row;
            }
          }
          return ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Text(
                spendingCategoryName(args.categoryId),
                style: WhyNotTextStyles.serif(size: 30),
              ),
              const SizedBox(height: 6),
              Text(
                spendingMonthLabel(args.month),
                style: WhyNotTextStyles.muted(size: 14),
              ),
              const SizedBox(height: 20),
              SpendingStatus(controller: c),
              if (c.calculating)
                const Center(child: CircularProgressIndicator())
              else if (!c.hasData)
                const Text('Sign in to view your spending.')
              else if (category == null)
                const SpendingCard(
                  child: Text(
                    'No purchased products in this category for this month.',
                  ),
                )
              else ...[
                SpendingCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'CATEGORY TOTAL',
                        style: WhyNotTextStyles.muted(size: 11),
                      ),
                      const SizedBox(height: 8),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          spendingMoney(category.totalCents),
                          style: WhyNotTextStyles.serif(size: 36),
                        ),
                      ),
                      Text(
                        '${category.products.length} purchased products',
                        style: WhyNotTextStyles.muted(size: 12),
                      ),
                    ],
                  ),
                ),
                for (final product in category.products)
                  SpendingCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          product.name.isEmpty ? 'Product' : product.name,
                          style: WhyNotTextStyles.serif(size: 22),
                        ),
                        if (product.brand.isNotEmpty)
                          Text(
                            product.brand,
                            style: WhyNotTextStyles.muted(size: 12),
                          ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 16,
                          runSpacing: 6,
                          children: [
                            Text(
                              spendingMoney(product.amountCents),
                              style: const TextStyle(
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            Text(
                              MaterialLocalizations.of(context).formatShortDate(
                                spendingDate(product.purchasedAt!),
                              ),
                              style: WhyNotTextStyles.muted(size: 12),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
              ],
              Text(
                'Recorded product prices · Colombia purchase dates',
                style: WhyNotTextStyles.muted(size: 11),
              ),
            ],
          );
        },
      ),
    );
  }
}

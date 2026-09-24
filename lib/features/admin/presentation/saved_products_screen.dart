import 'package:flutter/material.dart';

import '../../../app/app_routes.dart';
import '../../../app/dependencies_scope.dart';
import '../../../app/whynot_theme.dart';
import '../../products/domain/product.dart';
import '../../profile/domain/user_profile.dart';
import 'widgets/admin_components.dart';

class SavedProductsScreen extends StatefulWidget {
  const SavedProductsScreen({super.key});

  @override
  State<SavedProductsScreen> createState() => _SavedProductsScreenState();
}

class _SavedProductsScreenState extends State<SavedProductsScreen> {
  var _selectedMetric = SavedProductsMetric.percentage;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Product>>(
      stream: context.dependencies.productController.watchAllProducts(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _page(const Text('Could not load products.'));
        }
        if (!snapshot.hasData) {
          return _page(const Center(child: CircularProgressIndicator()));
        }

        return StreamBuilder<List<UserProfile>>(
          stream: context.dependencies.profileController.watchAllProfiles(),
          builder: (context, profileSnapshot) {
            if (profileSnapshot.hasError) {
              return _page(const Text('Could not load profiles.'));
            }
            if (!profileSnapshot.hasData) {
              return _page(const Center(child: CircularProgressIndicator()));
            }

            final byOwner = <String, int>{};
            for (final product in snapshot.data!) {
              byOwner[product.ownerId] = (byOwner[product.ownerId] ?? 0) + 1;
            }
            final activeUsers = byOwner.length;
            final zeroProductUsers = profileSnapshot.data!
                .where((profile) => !byOwner.containsKey(profile.id))
                .length;
            final totalProducts = snapshot.data!.length;
            final singleUsers = byOwner.values
                .where((count) => count == 1)
                .length;
            final multipleUsers = activeUsers - singleUsers;
            final average = activeUsers == 0
                ? 0.0
                : totalProducts / activeUsers;
            final groupCounts = [0, 0, 0, 0, 0];
            for (final count in byOwner.values) {
              final index = count <= 5
                  ? 0
                  : count <= 10
                  ? 1
                  : count <= 20
                  ? 2
                  : count <= 50
                  ? 3
                  : 4;
              groupCounts[index] += 1;
            }

            final usersSelected = _selectedMetric == SavedProductsMetric.users;
            const labels = ['1–5', '6–10', '11–20', '21–50', '51+'];
            final bars = List.generate(5, (index) {
              final count = groupCounts[index];
              final share = activeUsers == 0 ? 0.0 : count / activeUsers;
              return SavedProductsDistributionBar(
                labels[index],
                usersSelected ? '$count' : '${(share * 100).round()}%',
                usersSelected ? count.toDouble() : share,
              );
            });
            final maxValue = usersSelected
                ? ((activeUsers + 2) ~/ 3 * 3).clamp(3, 1000000).toDouble()
                : 1.0;
            final yAxisLabels = usersSelected
                ? [for (var i = 3; i >= 0; i--) '${(maxValue * i / 3).round()}']
                : const ['100%', '67%', '33%', '0%'];

            return _page(
              Column(
                children: [
                  AdminSegmentedControl(
                    labels: const ['Saved products', 'Recommended'],
                    selectedIndex: 0,
                    onSelected: (index) {
                      if (index == 1) {
                        Navigator.pushReplacementNamed(
                          context,
                          AppRoutes.adminRecommendedProducts,
                        );
                      }
                    },
                  ),
                  const SizedBox(height: 18),
                  SavedProductsKpis(
                    average: average.toStringAsFixed(1),
                    singleUsers: singleUsers,
                    multipleUsers: multipleUsers,
                  ),
                  const SizedBox(height: 25),
                  SavedProductsActivationCard(
                    activeUsers: activeUsers,
                    totalProducts: totalProducts,
                  ),
                  const SizedBox(height: 16),
                  SavedProductsZeroUsersCard(count: zeroProductUsers),
                  const SizedBox(height: 23),
                  SavedProductsDistributionCard(
                    bars: bars,
                    maxValue: maxValue,
                    selectedMetric: _selectedMetric,
                    yAxisLabels: yAxisLabels,
                    note: '$activeUsers active users  •  Current products',
                    insight: 'The distribution includes active users only.',
                    onMetricSelected: (metric) =>
                        setState(() => _selectedMetric = metric),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _page(Widget content) => AdminPage(
    title: 'Saved products',
    subtitle: 'How many products has a user saved?',
    currentRoute: AppRoutes.adminSavedProducts,
    children: [const SizedBox(height: 25), content],
  );
}

class SavedProductsKpis extends StatelessWidget {
  const SavedProductsKpis({
    required this.average,
    required this.singleUsers,
    required this.multipleUsers,
    super.key,
  });

  final String average;
  final int singleUsers;
  final int multipleUsers;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: SavedProductsKpiCard(
            label: 'Average',
            value: average,
            unit: 'per active user',
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: SavedProductsSplitKpiCard(
            singleUsers: singleUsers,
            multipleUsers: multipleUsers,
          ),
        ),
      ],
    );
  }
}

class SavedProductsKpiCard extends StatelessWidget {
  const SavedProductsKpiCard({
    required this.label,
    required this.value,
    required this.unit,
    super.key,
  });

  final String label;
  final String value;
  final String unit;

  @override
  Widget build(BuildContext context) {
    return AdminSurface(
      height: 75,
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: adminLightStyle(size: 10)),
          const Spacer(),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(value, style: WhyNotTextStyles.serif(size: 24)),
              const SizedBox(width: 7),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    unit,
                    style: adminLightStyle(size: 9, color: Colors.black),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class SavedProductsSplitKpiCard extends StatelessWidget {
  const SavedProductsSplitKpiCard({
    required this.singleUsers,
    required this.multipleUsers,
    super.key,
  });

  final int singleUsers;
  final int multipleUsers;

  @override
  Widget build(BuildContext context) {
    return AdminSurface(
      height: 75,
      padding: const EdgeInsets.fromLTRB(14, 10, 10, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '1 product vs. 2+ products',
            style: adminLightStyle(size: 10),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const Spacer(),
          Row(
            children: [
              SavedProductsKpiPair(value: '$singleUsers'),
              Container(
                width: 1,
                height: 34,
                margin: const EdgeInsets.symmetric(horizontal: 8),
                color: Colors.black,
              ),
              SavedProductsKpiPair(value: '$multipleUsers'),
            ],
          ),
        ],
      ),
    );
  }
}

class SavedProductsKpiPair extends StatelessWidget {
  const SavedProductsKpiPair({required this.value, super.key});

  final String value;

  @override
  Widget build(BuildContext context) {
    return Text(value, style: WhyNotTextStyles.serif(size: 24));
  }
}

class SavedProductsActivationCard extends StatelessWidget {
  const SavedProductsActivationCard({
    required this.activeUsers,
    required this.totalProducts,
    super.key,
  });

  final int activeUsers;
  final int totalProducts;

  @override
  Widget build(BuildContext context) {
    return AdminSurface(
      height: 84,
      padding: const EdgeInsets.fromLTRB(16, 12, 20, 13),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Products currently saved',
                  style: adminBodyStyle(size: 11),
                ),
                const SizedBox(height: 6),
                Text(
                  'Deleted products are excluded',
                  style: adminLightStyle(size: 10),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('$totalProducts', style: WhyNotTextStyles.serif(size: 28)),
              Text(
                '$activeUsers active users',
                style: adminLightStyle(size: 9),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class SavedProductsZeroUsersCard extends StatelessWidget {
  const SavedProductsZeroUsersCard({required this.count, super.key});

  final int count;

  @override
  Widget build(BuildContext context) {
    return AdminSurface(
      height: 76,
      padding: const EdgeInsets.fromLTRB(16, 12, 20, 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('Users with 0 products', style: adminBodyStyle(size: 11)),
                const SizedBox(height: 5),
                Text('Activation opportunity', style: adminLightStyle(size: 9)),
              ],
            ),
          ),
          Text('$count', style: WhyNotTextStyles.serif(size: 28)),
        ],
      ),
    );
  }
}

enum SavedProductsMetric { users, percentage }

class SavedProductsDistributionCard extends StatelessWidget {
  const SavedProductsDistributionCard({
    required this.bars,
    required this.maxValue,
    required this.selectedMetric,
    required this.yAxisLabels,
    required this.note,
    required this.insight,
    required this.onMetricSelected,
    super.key,
  });

  final List<SavedProductsDistributionBar> bars;
  final double maxValue;
  final SavedProductsMetric selectedMetric;
  final List<String> yAxisLabels;
  final String note;
  final String insight;
  final ValueChanged<SavedProductsMetric> onMetricSelected;

  @override
  Widget build(BuildContext context) {
    return AdminSurface(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 27),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Distribution',
                  style: WhyNotTextStyles.serif(size: 20),
                ),
              ),
              SizedBox(
                width: 155,
                height: 32,
                child: AdminSegmentedControl(
                  labels: const ['Users', '% users'],
                  selectedIndex: selectedMetric == SavedProductsMetric.users
                      ? 0
                      : 1,
                  height: 32,
                  onSelected: (index) {
                    onMetricSelected(
                      index == 0
                          ? SavedProductsMetric.users
                          : SavedProductsMetric.percentage,
                    );
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          SizedBox(
            height: 181,
            child: CustomPaint(
              painter: SavedProductsDistributionChartPainter(
                bars: bars,
                maxValue: maxValue,
                yAxisLabels: yAxisLabels,
              ),
              child: const SizedBox.expand(),
            ),
          ),
          const SizedBox(height: 12),
          Center(
            child: Text(
              'Saved products per user',
              style: adminLightStyle(size: 10),
            ),
          ),
          const SizedBox(height: 24),
          Text(note, style: adminLightStyle(size: 10)),
          const SizedBox(height: 24),
          Text(insight, style: adminBodyStyle(size: 10)),
        ],
      ),
    );
  }
}

class SavedProductsDistributionChartPainter extends CustomPainter {
  const SavedProductsDistributionChartPainter({
    required this.bars,
    required this.maxValue,
    required this.yAxisLabels,
  });

  final List<SavedProductsDistributionBar> bars;
  final double maxValue;
  final List<String> yAxisLabels;

  @override
  void paint(Canvas canvas, Size size) {
    const leftAxis = 28.0;
    const top = 22.0;
    const chartHeight = 108.0;
    const labelGap = 10.0;
    const barWidth = 34.0;
    final bottom = top + chartHeight;
    final chartWidth = size.width - leftAxis - 8;
    final step = chartWidth / bars.length;
    final gridPaint = Paint()
      ..color = WhyNotColors.divider
      ..strokeWidth = 1;
    final textPainter = TextPainter(textDirection: TextDirection.ltr);

    void drawText(
      String text,
      Offset offset,
      TextStyle style, {
      double? width,
    }) {
      textPainter
        ..text = TextSpan(text: text, style: style)
        ..textAlign = TextAlign.left
        ..layout(maxWidth: width ?? double.infinity);
      textPainter.paint(canvas, offset);
    }

    void drawCenteredText(String text, Offset center, TextStyle style) {
      textPainter
        ..text = TextSpan(text: text, style: style)
        ..textAlign = TextAlign.center
        ..layout();
      textPainter.paint(
        canvas,
        Offset(center.dx - (textPainter.width / 2), center.dy),
      );
    }

    final axisStyle = adminLightStyle(size: 9);
    for (var index = 0; index < yAxisLabels.length; index += 1) {
      final tick = maxValue * (3 - index) / 3;
      final y = bottom - (tick / maxValue) * chartHeight;
      drawText(yAxisLabels[index], Offset(0, y - 7), axisStyle, width: 26);
      canvas.drawLine(
        Offset(leftAxis, y),
        Offset(size.width - 8, y),
        gridPaint,
      );
    }

    final barPaint = Paint()..color = adminBar;
    final valueStyle = adminBodyStyle(size: 9);

    for (var index = 0; index < bars.length; index += 1) {
      final bar = bars[index];
      final centerX = leftAxis + (step * index) + (step / 2);
      final barHeight = (bar.value / maxValue) * chartHeight;
      final rect = RRect.fromRectAndCorners(
        Rect.fromLTWH(
          centerX - (barWidth / 2),
          bottom - barHeight,
          barWidth,
          barHeight,
        ),
        topLeft: const Radius.circular(8),
        topRight: const Radius.circular(8),
        bottomLeft: const Radius.circular(2),
        bottomRight: const Radius.circular(2),
      );
      canvas.drawRRect(rect, barPaint);
      drawCenteredText(
        bar.valueLabel,
        Offset(centerX, bottom - barHeight - 17),
        valueStyle,
      );
      drawCenteredText(
        bar.label,
        Offset(centerX, bottom + labelGap),
        axisStyle,
      );
    }
  }

  @override
  bool shouldRepaint(
    covariant SavedProductsDistributionChartPainter oldDelegate,
  ) {
    return oldDelegate.bars != bars ||
        oldDelegate.maxValue != maxValue ||
        oldDelegate.yAxisLabels != yAxisLabels;
  }
}

class SavedProductsDistributionBar {
  const SavedProductsDistributionBar(this.label, this.valueLabel, this.value);

  final String label;
  final String valueLabel;
  final double value;
}

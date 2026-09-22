import 'package:flutter/material.dart';

import '../../../app/app_routes.dart';
import '../../../app/whynot_theme.dart';
import 'widgets/admin_components.dart';

class SavedProductsScreen extends StatefulWidget {
  const SavedProductsScreen({super.key});

  @override
  State<SavedProductsScreen> createState() => _SavedProductsScreenState();
}

class _SavedProductsScreenState extends State<SavedProductsScreen> {
  static const _percentageBars = [
    SavedProductsDistributionBar('1–5', '26%', 0.26),
    SavedProductsDistributionBar('6–10', '22%', 0.22),
    SavedProductsDistributionBar('11–20', '19%', 0.19),
    SavedProductsDistributionBar('21–50', '11%', 0.11),
    SavedProductsDistributionBar('51+', '4%', 0.04),
  ];

  static const _userBars = [
    SavedProductsDistributionBar('1–5', '29', 0.278),
    SavedProductsDistributionBar('6–10', '24', 0.235),
    SavedProductsDistributionBar('11–20', '20', 0.204),
    SavedProductsDistributionBar('21–50', '13', 0.117),
    SavedProductsDistributionBar('51+', '5', 0.043),
  ];

  var _selectedMetric = SavedProductsMetric.percentage;

  @override
  Widget build(BuildContext context) {
    final usersSelected = _selectedMetric == SavedProductsMetric.users;

    return AdminPage(
      title: 'Saved products',
      subtitle: 'How many products has a user saved?',
      currentRoute: AppRoutes.adminSavedProducts,
      children: [
        const SizedBox(height: 25),
        const SavedProductsKpis(),
        const SizedBox(height: 25),
        SavedProductsActivationCard(
          users: usersSelected ? '225 users' : '35 users',
        ),
        const SizedBox(height: 23),
        SavedProductsDistributionCard(
          bars: usersSelected ? _userBars : _percentageBars,
          selectedMetric: _selectedMetric,
          yAxisLabels: usersSelected
              ? const ['30', '20', '10', '0']
              : const ['30%', '20%', '10%', '0%'],
          note: '91 users  •  Last 30 days',
          insight: usersSelected
              ? '60 users save between 1 and 10 products.'
              : 'Most users save between 1 and 10 products.',
          onMetricSelected: (metric) {
            setState(() {
              _selectedMetric = metric;
            });
          },
        ),
      ],
    );
  }
}

class SavedProductsKpis extends StatelessWidget {
  const SavedProductsKpis({super.key});

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        Expanded(
          child: SavedProductsKpiCard(
            label: 'Average',
            value: '9.8',
            unit: 'products / user',
          ),
        ),
        SizedBox(width: 8),
        Expanded(child: SavedProductsSplitKpiCard()),
      ],
    );
  }
}

class SavedProductsKpiCard extends StatelessWidget {
  const SavedProductsKpiCard({
    required this.label,
    required this.value,
    required this.unit,
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
              const SizedBox(width: 13),
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  unit,
                  style: adminLightStyle(size: 9, color: Colors.black),
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
  const SavedProductsSplitKpiCard({super.key});

  @override
  Widget build(BuildContext context) {
    return AdminSurface(
      height: 75,
      padding: const EdgeInsets.fromLTRB(14, 10, 10, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '1 product saved vs. + 1 saved',
            style: adminLightStyle(size: 10),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const Spacer(),
          Row(
            children: [
              const SavedProductsKpiPair(value: '26'),
              Container(
                width: 1,
                height: 34,
                margin: const EdgeInsets.symmetric(horizontal: 8),
                color: Colors.black,
              ),
              const SavedProductsKpiPair(value: '65'),
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
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(value, style: WhyNotTextStyles.serif(size: 24)),
        const SizedBox(width: 4),
        Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Text(
            'users',
            style: adminLightStyle(size: 9, color: Colors.black),
          ),
        ),
      ],
    );
  }
}

class SavedProductsActivationCard extends StatelessWidget {
  const SavedProductsActivationCard({required this.users, super.key});

  final String users;

  @override
  Widget build(BuildContext context) {
    return AdminSurface(
      height: 76,
      padding: const EdgeInsets.fromLTRB(16, 12, 20, 13),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('0 products saved', style: adminBodyStyle(size: 11)),
                const SizedBox(height: 6),
                Text(
                  'Activation opportunity',
                  style: adminLightStyle(size: 10),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('18%', style: WhyNotTextStyles.serif(size: 28)),
              Text(users, style: adminLightStyle(size: 9)),
            ],
          ),
        ],
      ),
    );
  }
}

enum SavedProductsMetric { users, percentage }

class SavedProductsDistributionCard extends StatelessWidget {
  const SavedProductsDistributionCard({
    required this.bars,
    required this.selectedMetric,
    required this.yAxisLabels,
    required this.note,
    required this.insight,
    required this.onMetricSelected,
  });

  final List<SavedProductsDistributionBar> bars;
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
    required this.yAxisLabels,
  });

  final List<SavedProductsDistributionBar> bars;
  final List<String> yAxisLabels;

  @override
  void paint(Canvas canvas, Size size) {
    const leftAxis = 28.0;
    const top = 4.0;
    const chartHeight = 126.0;
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
      final tick = 0.3 - (index * 0.1);
      final y = bottom - (tick / 0.3) * chartHeight;
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
      final barHeight = (bar.value / 0.3) * chartHeight;
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
    return oldDelegate.bars != bars || oldDelegate.yAxisLabels != yAxisLabels;
  }
}

class SavedProductsDistributionBar {
  const SavedProductsDistributionBar(this.label, this.valueLabel, this.value);

  final String label;
  final String valueLabel;
  final double value;
}

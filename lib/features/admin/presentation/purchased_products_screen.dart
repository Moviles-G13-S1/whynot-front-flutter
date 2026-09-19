import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../app/app_routes.dart';
import '../../../app/whynot_theme.dart';
import 'widgets/admin_components.dart';

class PurchasedProductsScreen extends StatelessWidget {
  const PurchasedProductsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AdminPage(
      title: 'Purchased products',
      subtitle: 'By month and category',
      currentRoute: AppRoutes.adminPurchasedProducts,
      children: const [
        SizedBox(height: 13),
        _LatestMonthCard(),
        SizedBox(height: 16),
        AdminSegmentedControl(
          labels: ['6 months', '12 months', '24 months'],
          selectedIndex: 0,
        ),
        SizedBox(height: 12),
        _PurchasedChartCard(),
      ],
    );
  }
}

class _LatestMonthCard extends StatelessWidget {
  const _LatestMonthCard();

  @override
  Widget build(BuildContext context) {
    return AdminSurface(
      height: 88,
      padding: const EdgeInsets.fromLTRB(20, 15, 20, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('LATEST MONTH · JUN', style: adminMetaStyle(size: 10)),
          const Spacer(),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('143', style: WhyNotTextStyles.serif(size: 34, color: adminInk)),
              const SizedBox(width: 18),
              Padding(
                padding: const EdgeInsets.only(bottom: 7),
                child: Text('products purchased', style: adminLightStyle(size: 10)),
              ),
              const Spacer(),
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  '↑ 12.6% vs May',
                  style: adminBodyStyle(size: 11, color: const Color(0xFF337A4D)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PurchasedChartCard extends StatefulWidget {
  const _PurchasedChartCard();

  @override
  State<_PurchasedChartCard> createState() => _PurchasedChartCardState();
}

class _PurchasedChartCardState extends State<_PurchasedChartCard> {
  final Set<String> _activeCategories = {
    for (final item in _LegendItem.items) item.label,
  };

  _PurchasedSegmentSelection? _selectedSegment;

  void _toggleCategory(String label) {
    setState(() {
      if (_activeCategories.contains(label)) {
        if (_activeCategories.length == 1) return;
        _activeCategories.remove(label);
        _selectedSegment = null;
        return;
      }

      _activeCategories.add(label);
      _selectedSegment = null;
    });
  }

  void _handleChartTap(TapDownDetails details, Size size) {
    setState(() {
      _selectedSegment = _hitTestSegment(size, details.localPosition);
    });
  }

  @override
  Widget build(BuildContext context) {
    return AdminSurface(
      height: 369,
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 17),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('PURCHASED BY MONTH', style: adminMetaStyle(size: 10)),
          const SizedBox(height: 10),
          Text(
            'Count of first transitions to purchased',
            style: adminLightStyle(size: 10),
          ),
          const SizedBox(height: 13),
          SizedBox(
            height: 183,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final chartSize = Size(
                  constraints.maxWidth,
                  constraints.maxHeight,
                );

                return GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapDown: (details) => _handleChartTap(details, chartSize),
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      CustomPaint(
                        painter: _PurchasedStackedChartPainter(
                          activeCategories: Set.unmodifiable(_activeCategories),
                        ),
                        child: const SizedBox.expand(),
                      ),
                      if (_selectedSegment != null)
                        Positioned(
                          left: 20,
                          top: 12,
                          child: _PurchasedSegmentTooltip(
                            selection: _selectedSegment!,
                            onClose: () {
                              setState(() {
                                _selectedSegment = null;
                              });
                            },
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 5),
          _PurchasedLegend(
            activeCategories: _activeCategories,
            onToggle: _toggleCategory,
          ),
          const Spacer(),
          Center(
            child: Text(
              'Tap a category to hide/show · Tap a segment for details',
              style: adminLightStyle(size: 9),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  _PurchasedSegmentSelection? _hitTestSegment(Size size, Offset offset) {
    const leftAxis = 28.0;
    const plotBottom = 145.0;
    const barWidth = 24.0;
    const maxValue = 150.0;
    const plotTop = 15.0;
    final plotHeight = plotBottom - plotTop;
    final plotRight = size.width - 8;
    final step = (plotRight - leftAxis) / _PurchasedStackedChartPainter.months.length;
    final activeSegments = _PurchasedStackedChartPainter.segments
        .where((segment) => _activeCategories.contains(segment.label))
        .toList();

    for (var monthIndex = 0;
        monthIndex < _PurchasedStackedChartPainter.months.length;
        monthIndex += 1) {
      final centerX = leftAxis + (step * monthIndex) + (step / 2);
      var currentBottom = plotBottom;
      final monthTotal = activeSegments.fold<double>(
        0,
        (total, segment) => total + segment.values[monthIndex],
      );

      for (final segment in activeSegments) {
        final value = segment.values[monthIndex];
        final height = (value / maxValue) * plotHeight;
        final rect = Rect.fromLTWH(
          centerX - (barWidth / 2),
          currentBottom - height,
          barWidth,
          height,
        ).inflate(3);

        if (rect.contains(offset)) {
          return _PurchasedSegmentSelection(
            month: _PurchasedStackedChartPainter.months[monthIndex],
            category: segment.label,
            value: value,
            monthTotal: monthTotal,
          );
        }

        currentBottom -= height;
      }
    }

    return null;
  }
}

class _PurchasedSegmentTooltip extends StatelessWidget {
  const _PurchasedSegmentTooltip({
    required this.selection,
    required this.onClose,
  });

  final _PurchasedSegmentSelection selection;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        width: 270,
        height: 112,
        padding: const EdgeInsets.fromLTRB(17, 15, 17, 14),
        decoration: BoxDecoration(
          color: const Color(0xFFF6F1E9),
          border: Border.all(color: const Color(0xFFBAAD9C)),
          borderRadius: BorderRadius.circular(18),
          boxShadow: const [
            BoxShadow(
              color: Color(0x291A1714),
              blurRadius: 20,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${selection.month} · ${selection.category}',
                  style: adminBodyStyle(size: 13),
                ),
                const SizedBox(height: 9),
                Text(
                  '${selection.roundedValue} products · ${selection.shareLabel} of ${selection.month} total',
                  style: adminLightStyle(size: 11, color: adminInk),
                ),
                const Spacer(),
                Text('Tap outside to close', style: adminLightStyle(size: 9)),
              ],
            ),
            Positioned(
              right: -1,
              top: -2,
              child: SizedBox.square(
                dimension: 24,
                child: IconButton(
                  onPressed: onClose,
                  padding: EdgeInsets.zero,
                  icon: const Icon(Icons.close_rounded, size: 18),
                  color: adminInk,
                  tooltip: 'Close tooltip',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PurchasedLegend extends StatelessWidget {
  const _PurchasedLegend({
    required this.activeCategories,
    required this.onToggle,
  });

  final Set<String> activeCategories;
  final ValueChanged<String> onToggle;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 22,
      runSpacing: 13,
      children: _LegendItem.items
          .map(
            (item) {
              final selected = activeCategories.contains(item.label);
              final itemColor = selected
                  ? item.color
                  : const Color(0xFFCFC8BE);
              final textColor = selected
                  ? const Color(0xFF45413C)
                  : adminMuted.withValues(alpha: 0.55);

              return InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () => onToggle(item.label),
                child: SizedBox(
                  width: item.label == 'Entertainment' ? 118 : 81,
                  height: 18,
                  child: Row(
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: itemColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          item.label,
                          style: adminLightStyle(size: 10, color: textColor),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          )
          .toList(),
    );
  }
}

class _PurchasedStackedChartPainter extends CustomPainter {
  const _PurchasedStackedChartPainter({required this.activeCategories});

  final Set<String> activeCategories;

  static const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun'];
  static const segments = [
    _StackSegment('Tech', Color(0xFF4F7CAC), [22, 26, 21, 28, 31, 34]),
    _StackSegment('Beauty', Color(0xFFD984A7), [10, 12, 13, 15, 16, 18]),
    _StackSegment('Clothing', Color(0xFF8B6DB1), [14, 16, 15, 18, 19, 21]),
    _StackSegment('Home', Color(0xFF6FA17B), [15, 18, 17, 20, 21, 23]),
    _StackSegment(
      'Entertainment',
      Color(0xFFD98B4E),
      [9, 11, 12, 14, 15, 17],
    ),
    _StackSegment('Events', Color(0xFFE0BE55), [6, 8, 7, 10, 11, 13]),
    _StackSegment('Travel', Color(0xFF58AAA4), [8, 11, 11, 13, 14, 17]),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    const leftAxis = 28.0;
    const plotTop = 15.0;
    const plotBottom = 145.0;
    const barWidth = 24.0;
    const maxValue = 150.0;
    final plotHeight = plotBottom - plotTop;
    final plotRight = size.width - 8;
    final activeSegments = segments
        .where((segment) => activeCategories.contains(segment.label))
        .toList();
    final gridPaint = Paint()
      ..color = adminDivider
      ..strokeWidth = 1;
    final textPainter = TextPainter(textDirection: TextDirection.ltr);

    void drawCentered(String text, Offset center, TextStyle style) {
      textPainter
        ..text = TextSpan(text: text, style: style)
        ..textAlign = TextAlign.center
        ..layout();
      textPainter.paint(
        canvas,
        Offset(center.dx - (textPainter.width / 2), center.dy),
      );
    }

    void drawRight(String text, Offset rightTop, TextStyle style) {
      textPainter
        ..text = TextSpan(text: text, style: style)
        ..textAlign = TextAlign.right
        ..layout();
      textPainter.paint(
        canvas,
        Offset(rightTop.dx - textPainter.width, rightTop.dy),
      );
    }

    final axisStyle = adminLightStyle(size: 8);
    for (final tick in [150, 100, 50, 0]) {
      final y = plotBottom - (tick / maxValue) * plotHeight;
      canvas.drawLine(Offset(leftAxis, y), Offset(plotRight, y), gridPaint);
      drawRight('$tick', Offset(leftAxis - 4, y - 5), axisStyle);
    }

    final step = (plotRight - leftAxis) / months.length;
    for (var monthIndex = 0; monthIndex < months.length; monthIndex += 1) {
      final centerX = leftAxis + (step * monthIndex) + (step / 2);
      var currentBottom = plotBottom;
      for (final segment in activeSegments) {
        final height = (segment.values[monthIndex] / maxValue) * plotHeight;
        final rect = Rect.fromLTWH(
          centerX - (barWidth / 2),
          currentBottom - height,
          barWidth,
          height,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(rect, const Radius.circular(2)),
          Paint()..color = segment.color,
        );
        currentBottom -= height;
      }
      drawCentered(months[monthIndex], Offset(centerX, 154), axisStyle);
    }
  }

  @override
  bool shouldRepaint(covariant _PurchasedStackedChartPainter oldDelegate) {
    return !setEquals(oldDelegate.activeCategories, activeCategories);
  }
}

class _PurchasedSegmentSelection {
  const _PurchasedSegmentSelection({
    required this.month,
    required this.category,
    required this.value,
    required this.monthTotal,
  });

  final String month;
  final String category;
  final double value;
  final double monthTotal;

  int get roundedValue => value.round();

  String get shareLabel {
    final share = monthTotal == 0 ? 0 : (value / monthTotal) * 100;
    return '${share.toStringAsFixed(1)}%';
  }
}

class _StackSegment {
  const _StackSegment(this.label, this.color, this.values);

  final String label;
  final Color color;
  final List<double> values;
}

class _LegendItem {
  const _LegendItem(this.label, this.color);

  static const items = [
    _LegendItem('Tech', Color(0xFF4F7CAC)),
    _LegendItem('Beauty', Color(0xFFD984A7)),
    _LegendItem('Clothing', Color(0xFF8B6DB1)),
    _LegendItem('Home', Color(0xFF6FA17B)),
    _LegendItem('Entertainment', Color(0xFFD98B4E)),
    _LegendItem('Events', Color(0xFFE0BE55)),
    _LegendItem('Travel', Color(0xFF58AAA4)),
  ];

  final String label;
  final Color color;
}

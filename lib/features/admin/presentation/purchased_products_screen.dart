import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../app/app_routes.dart';
import '../../../app/dependencies_scope.dart';
import '../../../app/whynot_theme.dart';
import '../../products/domain/product.dart';
import 'widgets/admin_components.dart';

class PurchasedProductsScreen extends StatefulWidget {
  const PurchasedProductsScreen({super.key});

  @override
  State<PurchasedProductsScreen> createState() =>
      _PurchasedProductsScreenState();
}

class _PurchasedProductsScreenState extends State<PurchasedProductsScreen> {
  static const _monthNames = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  static const _colors = [
    Color(0xFF4F7CAC),
    Color(0xFFD984A7),
    Color(0xFF8B6DB1),
    Color(0xFF6FA17B),
    Color(0xFFD98B4E),
    Color(0xFFE0BE55),
    Color(0xFF58AAA4),
    Color(0xFF817D78),
  ];

  int _windowMonths = 6;

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

        final now = DateTime.now();
        final months = List.generate(
          _windowMonths,
          (index) => DateTime(now.year, now.month - _windowMonths + index + 1),
        );
        final counts = <String, List<double>>{};
        for (final product in snapshot.data!) {
          final date = product.purchasedAt;
          if (!product.purchased || date == null) continue;
          final monthIndex = months.indexWhere(
            (month) => month.year == date.year && month.month == date.month,
          );
          if (monthIndex < 0) continue;
          final values = counts.putIfAbsent(
            product.categoryId,
            () => List.filled(_windowMonths, 0),
          );
          values[monthIndex] += 1;
        }
        final categories = counts.keys.toList()..sort();
        final segments = [
          for (var index = 0; index < categories.length; index++)
            _StackSegment(
              categories[index],
              _colors[index % _colors.length],
              counts[categories[index]]!,
            ),
        ];
        final monthLabels = [
          for (final month in months) _monthNames[month.month - 1],
        ];
        final currentCount = segments.fold<int>(
          0,
          (sum, segment) => sum + segment.values.last.round(),
        );
        final previousCount = segments.fold<int>(
          0,
          (sum, segment) => sum + segment.values[_windowMonths - 2].round(),
        );
        final peak = List.generate(
          _windowMonths,
          (index) => segments.fold<double>(
            0,
            (sum, segment) => sum + segment.values[index],
          ),
        ).fold<double>(0, (max, value) => value > max ? value : max);
        final maxValue = ((peak.ceil() + 2) ~/ 3 * 3)
            .clamp(3, 1000000)
            .toDouble();

        return _page(
          Column(
            children: [
              _LatestMonthCard(
                month: _monthNames[now.month - 1],
                count: currentCount,
                previousCount: previousCount,
              ),
              const SizedBox(height: 16),
              AdminSegmentedControl(
                labels: const ['6 months', '12 months', '24 months'],
                selectedIndex: [6, 12, 24].indexOf(_windowMonths),
                onSelected: (index) =>
                    setState(() => _windowMonths = [6, 12, 24][index]),
              ),
              const SizedBox(height: 12),
              _PurchasedChartCard(
                key: ValueKey(_windowMonths),
                monthLabels: monthLabels,
                months: months,
                segments: segments,
                maxValue: maxValue,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _page(Widget content) => AdminPage(
    title: 'Purchased products',
    subtitle: 'By month and category',
    currentRoute: AppRoutes.adminPurchasedProducts,
    children: [const SizedBox(height: 13), content],
  );
}

class _LatestMonthCard extends StatelessWidget {
  const _LatestMonthCard({
    required this.month,
    required this.count,
    required this.previousCount,
  });

  final String month;
  final int count;
  final int previousCount;

  @override
  Widget build(BuildContext context) {
    return AdminSurface(
      height: 88,
      padding: const EdgeInsets.fromLTRB(20, 15, 20, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'CURRENT MONTH · ${month.toUpperCase()}',
                  style: adminMetaStyle(size: 10),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                'Previous: $previousCount',
                style: adminLightStyle(size: 10),
              ),
            ],
          ),
          const Spacer(),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '$count',
                style: WhyNotTextStyles.serif(size: 34, color: adminInk),
              ),
              const SizedBox(width: 18),
              Padding(
                padding: const EdgeInsets.only(bottom: 7),
                child: Text(
                  'products purchased',
                  style: adminLightStyle(size: 10),
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
  const _PurchasedChartCard({
    required this.monthLabels,
    required this.months,
    required this.segments,
    required this.maxValue,
    super.key,
  });

  final List<String> monthLabels;
  final List<DateTime> months;
  final List<_StackSegment> segments;
  final double maxValue;

  @override
  State<_PurchasedChartCard> createState() => _PurchasedChartCardState();
}

class _PurchasedChartCardState extends State<_PurchasedChartCard> {
  final Set<String> _hiddenCategories = {};

  _PurchasedSegmentSelection? _selectedSegment;

  @override
  void didUpdateWidget(covariant _PurchasedChartCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.segments != widget.segments) {
      _selectedSegment = null;
    }
  }

  void _toggleCategory(String label) {
    setState(() {
      if (!_hiddenCategories.contains(label)) {
        final visible = widget.segments
            .where((segment) => !_hiddenCategories.contains(segment.label))
            .length;
        if (visible == 1) return;
        _hiddenCategories.add(label);
        _selectedSegment = null;
        return;
      }

      _hiddenCategories.remove(label);
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
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 17),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('PURCHASED BY MONTH', style: adminMetaStyle(size: 10)),
          const SizedBox(height: 10),
          Text('Existing purchased products', style: adminLightStyle(size: 10)),
          const SizedBox(height: 13),
          SizedBox(
            height: 183,
            child: LayoutBuilder(
              builder: (context, viewport) {
                final minimumWidth = widget.months.length * 44.0 + 28;
                final chartWidth = viewport.maxWidth > minimumWidth
                    ? viewport.maxWidth
                    : minimumWidth;
                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SizedBox(
                    width: chartWidth,
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final chartSize = Size(
                          constraints.maxWidth,
                          constraints.maxHeight,
                        );
                        return GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTapDown: (details) =>
                              _handleChartTap(details, chartSize),
                          child: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              CustomPaint(
                                painter: _PurchasedStackedChartPainter(
                                  monthLabels: widget.monthLabels,
                                  segments: widget.segments,
                                  maxValue: widget.maxValue,
                                  hiddenCategories: Set.unmodifiable(
                                    _hiddenCategories,
                                  ),
                                ),
                                child: const SizedBox.expand(),
                              ),
                              if (_selectedSegment != null)
                                Positioned(
                                  left: 20,
                                  top: 12,
                                  child: _PurchasedSegmentTooltip(
                                    selection: _selectedSegment!,
                                    onClose: () =>
                                        setState(() => _selectedSegment = null),
                                  ),
                                ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 5),
          _PurchasedLegend(
            segments: widget.segments,
            hiddenCategories: _hiddenCategories,
            onToggle: _toggleCategory,
          ),
          const SizedBox(height: 18),
          Center(
            child: Text(
              widget.segments.isEmpty
                  ? 'No purchases in this period'
                  : 'Tap a category to hide/show · Tap a segment for details',
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
    const plotTop = 15.0;
    final plotHeight = plotBottom - plotTop;
    final plotRight = size.width - 8;
    final step = (plotRight - leftAxis) / widget.months.length;
    final activeSegments = widget.segments
        .where((segment) => !_hiddenCategories.contains(segment.label))
        .toList();

    for (
      var monthIndex = 0;
      monthIndex < widget.months.length;
      monthIndex += 1
    ) {
      final centerX = leftAxis + (step * monthIndex) + (step / 2);
      var currentBottom = plotBottom;
      final monthTotal = activeSegments.fold<double>(
        0,
        (total, segment) => total + segment.values[monthIndex],
      );

      for (final segment in activeSegments) {
        final value = segment.values[monthIndex];
        final height = (value / widget.maxValue) * plotHeight;
        final rect = Rect.fromLTWH(
          centerX - (barWidth / 2),
          currentBottom - height,
          barWidth,
          height,
        ).inflate(3);

        if (rect.contains(offset)) {
          return _PurchasedSegmentSelection(
            month:
                '${widget.monthLabels[monthIndex]} ${widget.months[monthIndex].year}',
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
    required this.segments,
    required this.hiddenCategories,
    required this.onToggle,
  });

  final List<_StackSegment> segments;
  final Set<String> hiddenCategories;
  final ValueChanged<String> onToggle;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 22,
      runSpacing: 13,
      children: segments.map((item) {
        final selected = !hiddenCategories.contains(item.label);
        final itemColor = selected ? item.color : const Color(0xFFCFC8BE);
        final textColor = selected
            ? const Color(0xFF45413C)
            : adminMuted.withValues(alpha: 0.55);

        return InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => onToggle(item.label),
          child: SizedBox(
            width: item.label.length > 10 ? 118 : 81,
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
      }).toList(),
    );
  }
}

class _PurchasedStackedChartPainter extends CustomPainter {
  const _PurchasedStackedChartPainter({
    required this.monthLabels,
    required this.segments,
    required this.maxValue,
    required this.hiddenCategories,
  });

  final List<String> monthLabels;
  final List<_StackSegment> segments;
  final double maxValue;
  final Set<String> hiddenCategories;

  @override
  void paint(Canvas canvas, Size size) {
    const leftAxis = 28.0;
    const plotTop = 15.0;
    const plotBottom = 145.0;
    const barWidth = 24.0;
    final plotHeight = plotBottom - plotTop;
    final plotRight = size.width - 8;
    final activeSegments = segments
        .where((segment) => !hiddenCategories.contains(segment.label))
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
    for (final tick in [maxValue, maxValue * 2 / 3, maxValue / 3, 0.0]) {
      final y = plotBottom - (tick / maxValue) * plotHeight;
      canvas.drawLine(Offset(leftAxis, y), Offset(plotRight, y), gridPaint);
      drawRight('${tick.round()}', Offset(leftAxis - 4, y - 5), axisStyle);
    }

    final step = (plotRight - leftAxis) / monthLabels.length;
    for (var monthIndex = 0; monthIndex < monthLabels.length; monthIndex += 1) {
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
      drawCentered(monthLabels[monthIndex], Offset(centerX, 154), axisStyle);
    }
  }

  @override
  bool shouldRepaint(covariant _PurchasedStackedChartPainter oldDelegate) {
    return !setEquals(oldDelegate.hiddenCategories, hiddenCategories) ||
        oldDelegate.segments != segments ||
        oldDelegate.monthLabels != monthLabels ||
        oldDelegate.maxValue != maxValue;
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

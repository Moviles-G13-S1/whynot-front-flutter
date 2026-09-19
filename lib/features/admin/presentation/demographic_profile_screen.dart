import 'package:flutter/material.dart';

import '../../../app/app_routes.dart';
import '../../../app/whynot_theme.dart';
import 'widgets/admin_components.dart';

class DemographicProfileScreen extends StatelessWidget {
  const DemographicProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AdminPage(
      title: 'Demographic profile',
      subtitle: 'Audience insights by product category',
      currentRoute: AppRoutes.adminDemographicProfile,
      titleSize: 27,
      children: const [
        SizedBox(height: 14),
        _CategorySelector(),
        SizedBox(height: 16),
        _AgeCard(),
        SizedBox(height: 16),
        _GenderCard(),
        SizedBox(height: 16),
        _TopCitiesCard(),
      ],
    );
  }
}

class _CategorySelector extends StatelessWidget {
  const _CategorySelector();

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(21),
      child: SizedBox(
        height: 42,
        child: ListView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          children: [
            Container(
              width: 650,
              decoration: BoxDecoration(
                color: const Color(0xFFF0EBE3),
                borderRadius: BorderRadius.circular(21),
              ),
              child: Row(
                children: const [
                  _CategoryPill(label: 'Tech', selected: true, width: 74),
                  _CategoryPill(label: 'Beauty', width: 84),
                  _CategoryPill(label: 'Clothing', width: 94),
                  _CategoryPill(label: 'Home', width: 76),
                  _CategoryPill(label: 'Entertainment', width: 132),
                  _CategoryPill(label: 'Events', width: 82),
                  _CategoryPill(label: 'Travel', width: 78),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryPill extends StatelessWidget {
  const _CategoryPill({
    required this.label,
    required this.width,
    this.selected = false,
  });

  final String label;
  final double width;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: 36,
      margin: EdgeInsets.only(left: selected ? 3 : 0),
      alignment: Alignment.center,
      decoration: selected
          ? BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
            )
          : null,
      child: Text(
        label,
        style: adminBodyStyle(
          size: 10,
          color: selected ? adminInk : adminMuted,
        ),
      ),
    );
  }
}

class _AgeCard extends StatelessWidget {
  const _AgeCard();

  @override
  Widget build(BuildContext context) {
    return AdminSurface(
      height: 200,
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 27),
      child: Column(
        children: [
          Row(
            children: [
              Text('AGE', style: adminMetaStyle(size: 10)),
              const Spacer(),
              Text('Median age', style: adminLightStyle(size: 10)),
              const SizedBox(width: 14),
              Text('29', style: WhyNotTextStyles.serif(size: 22, color: adminInk)),
              const SizedBox(width: 8),
            ],
          ),
          const SizedBox(height: 14),
          Expanded(
            child: CustomPaint(
              painter: _AgeChartPainter(),
              child: const SizedBox.expand(),
            ),
          ),
        ],
      ),
    );
  }
}

class _GenderCard extends StatelessWidget {
  const _GenderCard();

  @override
  Widget build(BuildContext context) {
    return AdminSurface(
      height: 118,
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('GENDER', style: adminMetaStyle(size: 10)),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(7),
            child: SizedBox(
              height: 30,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: const [
                  Expanded(flex: 48, child: ColoredBox(color: Color(0xFFB99875))),
                  Expanded(flex: 44, child: ColoredBox(color: Color(0xFF89847E))),
                  Expanded(flex: 8, child: ColoredBox(color: Color(0xFFE8DBC9))),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _GenderLegendItem(
                  color: Color(0xFFB99875),
                  label: 'Women 48%',
                ),
                _GenderLegendItem(
                  color: Color(0xFF89847E),
                  label: 'Men 44%',
                ),
                _GenderLegendItem(
                  color: Color(0xFFE8DBC9),
                  label: 'Other / N.A. 8%',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GenderLegendItem extends StatelessWidget {
  const _GenderLegendItem({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 9,
          height: 9,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            label,
            style: adminLightStyle(size: 9, color: adminInk),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class _TopCitiesCard extends StatelessWidget {
  const _TopCitiesCard();

  static const _cities = [
    _CityShare('Bogotá', 34),
    _CityShare('Medellín', 21),
    _CityShare('Cali', 14),
    _CityShare('Barranquilla', 9),
    _CityShare('Other', 22),
  ];

  @override
  Widget build(BuildContext context) {
    return AdminSurface(
      height: 250,
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 17),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('TOP CITIES', style: adminMetaStyle(size: 10)),
              const Spacer(),
              Text(
                'Share of Tech-category users',
                style: adminLightStyle(size: 9),
              ),
            ],
          ),
          const SizedBox(height: 22),
          for (final city in _cities) ...[
            _CityShareRow(city: city),
            const SizedBox(height: 15),
          ],
          const Spacer(),
          Text(
            'Users with at least one product saved in Tech',
            style: adminLightStyle(size: 9),
          ),
        ],
      ),
    );
  }
}

class _CityShareRow extends StatelessWidget {
  const _CityShareRow({required this.city});

  final _CityShare city;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 86,
          child: Text(city.name, style: adminLightStyle(size: 9, color: adminInk)),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Stack(
              children: [
                Container(height: 16, color: const Color(0xFFE8E0D4)),
                FractionallySizedBox(
                  widthFactor: city.percent / 34,
                  child: Container(
                    height: 16,
                    decoration: BoxDecoration(
                      color: city.percent == 34
                          ? adminBar
                          : const Color(0xFFB8B0A5),
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        SizedBox(
          width: 36,
          child: Text(
            '${city.percent}%',
            textAlign: TextAlign.right,
            style: adminBodyStyle(size: 9),
          ),
        ),
      ],
    );
  }
}

class _AgeChartPainter extends CustomPainter {
  final _items = const [
    _AgeBar('18–24', '28%', 0.28),
    _AgeBar('25–34', '41%', 0.41),
    _AgeBar('35–44', '20%', 0.20),
    _AgeBar('45–54', '8%', 0.08),
    _AgeBar('55+', '3%', 0.03),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    const baselineOffset = 20.0;
    const barWidth = 36.0;
    final baseline = size.height - baselineOffset;
    final usableHeight = size.height - 34;
    final step = size.width / _items.length;
    final textPainter = TextPainter(textDirection: TextDirection.ltr);
    final baselinePaint = Paint()
      ..color = adminDivider
      ..strokeWidth = 1;

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

    canvas.drawLine(
      Offset(8, baseline),
      Offset(size.width - 8, baseline),
      baselinePaint,
    );

    for (var index = 0; index < _items.length; index += 1) {
      final item = _items[index];
      final centerX = (step * index) + (step / 2);
      final height = (item.value / 0.41) * (usableHeight - 20);
      final rect = RRect.fromRectAndCorners(
        Rect.fromLTWH(centerX - (barWidth / 2), baseline - height, barWidth, height),
        topLeft: const Radius.circular(6),
        topRight: const Radius.circular(6),
        bottomLeft: const Radius.circular(4),
        bottomRight: const Radius.circular(4),
      );
      canvas.drawRRect(
        rect,
        Paint()
          ..color = index == 1 ? const Color(0xFF988B7B) : const Color(0xFFB9B0A5),
      );
      drawCentered(item.percent, Offset(centerX, baseline - height - 14), adminBodyStyle(size: 9));
      drawCentered(item.label, Offset(centerX, baseline + 9), adminLightStyle(size: 8));
    }
  }

  @override
  bool shouldRepaint(covariant _AgeChartPainter oldDelegate) {
    return false;
  }
}

class _AgeBar {
  const _AgeBar(this.label, this.percent, this.value);

  final String label;
  final String percent;
  final double value;
}

class _CityShare {
  const _CityShare(this.name, this.percent);

  final String name;
  final double percent;
}

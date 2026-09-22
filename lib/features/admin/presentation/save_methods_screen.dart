import 'package:flutter/material.dart';

import '../../../app/app_routes.dart';
import '../../../app/whynot_theme.dart';
import 'widgets/admin_components.dart';

class SaveMethodsScreen extends StatelessWidget {
  const SaveMethodsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AdminPage(
      title: 'Save methods',
      subtitle: 'What percentage of users use both methods?',
      currentRoute: AppRoutes.adminSaveMethods,
      children: const [
        SizedBox(height: 13),
        _BothMethodsKpi(),
        SizedBox(height: 16),
        _MethodsUsedCard(),
        SizedBox(height: 16),
        _ClassificationCard(),
      ],
    );
  }
}

class _BothMethodsKpi extends StatelessWidget {
  const _BothMethodsKpi();

  @override
  Widget build(BuildContext context) {
    return AdminSurface(
      height: 98,
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 17),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('BOTH METHODS', style: adminMetaStyle(size: 10)),
          const Spacer(),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '31%',
                style: WhyNotTextStyles.serif(size: 35, color: adminInk),
              ),
              const SizedBox(width: 26),
              Padding(
                padding: const EdgeInsets.only(bottom: 9),
                child: Text(
                  'of active savers · last 30 days',
                  style: adminLightStyle(size: 11),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MethodsUsedCard extends StatelessWidget {
  const _MethodsUsedCard();

  @override
  Widget build(BuildContext context) {
    return AdminSurface(
      height: 258,
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('METHODS USED · LAST 30 DAYS', style: adminMetaStyle(size: 10)),
          const SizedBox(height: 10),
          Text(
            'Among users who saved at least 1 product',
            style: adminLightStyle(size: 11),
          ),
          const SizedBox(height: 17),
          const _StackedMethodBar(),
          const SizedBox(height: 20),
          const _MethodLegendRow(
            color: adminBar,
            label: 'Only automatic',
            value: '52%',
          ),
          const SizedBox(height: 17),
          const _MethodLegendRow(
            color: Color(0xFFB09475),
            label: 'Both methods',
            value: '31%',
          ),
          const SizedBox(height: 17),
          const _MethodLegendRow(
            color: Color(0xFFE8DBC9),
            label: 'Only manual',
            value: '17%',
          ),
          const Spacer(),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              'Segments total 100%',
              style: adminLightStyle(size: 10),
            ),
          ),
        ],
      ),
    );
  }
}

class _StackedMethodBar extends StatelessWidget {
  const _StackedMethodBar();

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(9),
      child: SizedBox(
        height: 46,
        child: Row(
          children: const [
            _MethodBarSegment(
              flex: 52,
              color: adminBar,
              label: '52%',
              labelColor: Colors.white,
            ),
            _MethodBarSegment(
              flex: 31,
              color: Color(0xFFB09475),
              label: '31%',
              labelColor: Colors.white,
            ),
            _MethodBarSegment(
              flex: 17,
              color: Color(0xFFE8DBC9),
              label: '17%',
              labelColor: adminInk,
            ),
          ],
        ),
      ),
    );
  }
}

class _MethodBarSegment extends StatelessWidget {
  const _MethodBarSegment({
    required this.flex,
    required this.color,
    required this.label,
    required this.labelColor,
  });

  final int flex;
  final Color color;
  final String label;
  final Color labelColor;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      flex: flex,
      child: Container(
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.only(left: 12),
        color: color,
        child: Text(label, style: adminBodyStyle(size: 12, color: labelColor)),
      ),
    );
  }
}

class _MethodLegendRow extends StatelessWidget {
  const _MethodLegendRow({
    required this.color,
    required this.label,
    required this.value,
  });

  final Color color;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(label, style: adminLightStyle(size: 12, color: adminInk)),
        ),
        Text(value, style: adminBodyStyle(size: 12)),
      ],
    );
  }
}

class _ClassificationCard extends StatelessWidget {
  const _ClassificationCard();

  @override
  Widget build(BuildContext context) {
    return AdminSurface(
      height: 270,
      padding: const EdgeInsets.fromLTRB(20, 17, 20, 17),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          _ClassificationTitle(),
          SizedBox(height: 15),
          _RuleBlock(
            title: 'Only automatic',
            rule: 'Automatic >=1  ·  Manual 0',
          ),
          _RuleDivider(),
          _RuleBlock(
            title: 'Both methods',
            rule: 'Automatic >=1  ·  Manual >=1',
          ),
          _RuleDivider(),
          _RuleBlock(title: 'Only manual', rule: 'Manual >=1  ·  Automatic 0'),
          Spacer(),
          _ExclusionNote(),
        ],
      ),
    );
  }
}

class _ClassificationTitle extends StatelessWidget {
  const _ClassificationTitle();

  @override
  Widget build(BuildContext context) {
    return Text('CLASSIFICATION', style: adminMetaStyle(size: 10));
  }
}

class _RuleBlock extends StatelessWidget {
  const _RuleBlock({required this.title, required this.rule});

  final String title;
  final String rule;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 47,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: adminBodyStyle(size: 12)),
          const SizedBox(height: 6),
          Text(rule, style: adminLightStyle(size: 11)),
        ],
      ),
    );
  }
}

class _RuleDivider extends StatelessWidget {
  const _RuleDivider();

  @override
  Widget build(BuildContext context) {
    return const Divider(height: 1, color: adminDivider);
  }
}

class _ExclusionNote extends StatelessWidget {
  const _ExclusionNote();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 32,
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: adminPill,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        'Users with no saves in the period are excluded.',
        style: adminLightStyle(size: 10),
      ),
    );
  }
}

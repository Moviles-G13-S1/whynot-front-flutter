import 'package:flutter/material.dart';

import '../../../app/app_routes.dart';
import '../../../app/dependencies_scope.dart';
import '../../../app/whynot_theme.dart';
import '../../../shared/domain/category.dart';
import '../../../shared/domain/city.dart';
import '../../products/domain/product.dart';
import '../../profile/domain/user_profile.dart';
import '../domain/demographic_summary.dart';
import 'widgets/admin_components.dart';

class DemographicProfileScreen extends StatefulWidget {
  const DemographicProfileScreen({super.key});

  @override
  State<DemographicProfileScreen> createState() =>
      _DemographicProfileScreenState();
}

class _DemographicProfileScreenState extends State<DemographicProfileScreen> {
  Future<List<Category>>? _categories;
  Future<List<City>>? _cities;
  String? _selectedCategoryId;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _categories ??= context.dependencies.wishlistController.getCategories();
    _cities ??= context.dependencies.cityRepository.getCities();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Category>>(
      future: _categories,
      builder: (context, categorySnapshot) {
        if (categorySnapshot.hasError) {
          return _page(const Text('Could not load categories.'));
        }
        if (!categorySnapshot.hasData) {
          return _page(const Center(child: CircularProgressIndicator()));
        }
        final categories = categorySnapshot.data!;
        if (categories.isEmpty) {
          return _page(const Text('No categories found.'));
        }
        final selectedId =
            categories.any((item) => item.id == _selectedCategoryId)
            ? _selectedCategoryId!
            : categories.first.id;

        return FutureBuilder<List<City>>(
          future: _cities,
          builder: (context, citySnapshot) {
            if (citySnapshot.hasError) {
              return _page(const Text('Could not load cities.'));
            }
            if (!citySnapshot.hasData) {
              return _page(const Center(child: CircularProgressIndicator()));
            }
            return StreamBuilder<List<Product>>(
              stream: context.dependencies.productController.watchAllProducts(),
              builder: (context, productSnapshot) {
                if (productSnapshot.hasError) {
                  return _page(const Text('Could not load products.'));
                }
                if (!productSnapshot.hasData) {
                  return _page(
                    const Center(child: CircularProgressIndicator()),
                  );
                }
                return StreamBuilder<List<UserProfile>>(
                  stream: context.dependencies.profileController
                      .watchAllProfiles(),
                  builder: (context, profileSnapshot) {
                    if (profileSnapshot.hasError) {
                      return _page(const Text('Could not load profiles.'));
                    }
                    if (!profileSnapshot.hasData) {
                      return _page(
                        const Center(child: CircularProgressIndicator()),
                      );
                    }
                    final summary = DemographicSummary.fromData(
                      categoryId: selectedId,
                      products: productSnapshot.data!,
                      profiles: profileSnapshot.data!,
                      cityCatalog: citySnapshot.data!,
                    );
                    final selectedName = categories
                        .firstWhere((item) => item.id == selectedId)
                        .name;
                    return _page(
                      Column(
                        children: [
                          _CategorySelector(
                            categories: categories,
                            selectedId: selectedId,
                            onSelected: (id) =>
                                setState(() => _selectedCategoryId = id),
                          ),
                          const SizedBox(height: 16),
                          _AgeCard(summary: summary),
                          const SizedBox(height: 16),
                          _GenderCard(summary: summary),
                          const SizedBox(height: 16),
                          _TopCitiesCard(
                            summary: summary,
                            categoryName: selectedName,
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _page(Widget content) => AdminPage(
    title: 'Demographic profile',
    subtitle: 'Audience insights by product category',
    currentRoute: AppRoutes.adminDemographicProfile,
    titleSize: 27,
    children: [const SizedBox(height: 14), content],
  );
}

class _CategorySelector extends StatelessWidget {
  const _CategorySelector({
    required this.categories,
    required this.selectedId,
    required this.onSelected,
  });

  final List<Category> categories;
  final String selectedId;
  final ValueChanged<String> onSelected;

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
              decoration: BoxDecoration(
                color: const Color(0xFFF0EBE3),
                borderRadius: BorderRadius.circular(21),
              ),
              child: Row(
                children: [
                  for (final category in categories)
                    InkWell(
                      onTap: () => onSelected(category.id),
                      child: _CategoryPill(
                        label: category.name,
                        selected: category.id == selectedId,
                      ),
                    ),
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
  const _CategoryPill({required this.label, this.selected = false});

  final String label;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 74),
      padding: const EdgeInsets.symmetric(horizontal: 14),
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
  const _AgeCard({required this.summary});

  final DemographicSummary summary;

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
              Text(
                summary.medianAge,
                style: WhyNotTextStyles.serif(size: 22, color: adminInk),
              ),
              const SizedBox(width: 8),
            ],
          ),
          const SizedBox(height: 14),
          Expanded(
            child: CustomPaint(
              painter: _AgeChartPainter(summary.ages),
              child: const SizedBox.expand(),
            ),
          ),
        ],
      ),
    );
  }
}

class _GenderCard extends StatelessWidget {
  const _GenderCard({required this.summary});

  final DemographicSummary summary;

  static const _colors = [
    Color(0xFFB99875),
    Color(0xFF89847E),
    Color(0xFFE8DBC9),
  ];

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
                children: summary.userCount == 0
                    ? const [
                        Expanded(child: ColoredBox(color: Color(0xFFE8DBC9))),
                      ]
                    : [
                        for (
                          var index = 0;
                          index < summary.genders.length;
                          index++
                        )
                          if (summary.genders[index].count > 0)
                            Expanded(
                              flex: summary.genders[index].count,
                              child: ColoredBox(color: _colors[index]),
                            ),
                      ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                for (var index = 0; index < summary.genders.length; index++)
                  _GenderLegendItem(
                    color: _colors[index],
                    label:
                        '${summary.genders[index].label} ${summary.genders[index].percent}%',
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
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
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
  const _TopCitiesCard({required this.summary, required this.categoryName});

  final DemographicSummary summary;
  final String categoryName;

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
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Share of $categoryName users',
                  style: adminLightStyle(size: 9),
                  textAlign: TextAlign.right,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          for (final city in summary.cities) ...[
            _CityShareRow(
              city: city,
              maxCount: summary.cities.fold<int>(
                0,
                (max, item) => item.count > max ? item.count : max,
              ),
            ),
            const SizedBox(height: 15),
          ],
          const Spacer(),
          Text(
            '${summary.userCount} ${summary.userCount == 1 ? 'user' : 'users'} with a current product in $categoryName',
            style: adminLightStyle(size: 9),
          ),
        ],
      ),
    );
  }
}

class _CityShareRow extends StatelessWidget {
  const _CityShareRow({required this.city, required this.maxCount});

  final DemographicGroup city;
  final int maxCount;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 96,
          child: Text(
            city.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: adminLightStyle(size: 9, color: adminInk),
          ),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Stack(
              children: [
                Container(height: 16, color: const Color(0xFFE8E0D4)),
                FractionallySizedBox(
                  widthFactor: maxCount == 0 ? 0 : city.count / maxCount,
                  child: Container(
                    height: 16,
                    decoration: BoxDecoration(
                      color: city.count == maxCount && maxCount > 0
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
  const _AgeChartPainter(this.items);

  final List<DemographicGroup> items;

  @override
  void paint(Canvas canvas, Size size) {
    const baselineOffset = 20.0;
    const barWidth = 28.0;
    final baseline = size.height - baselineOffset;
    final usableHeight = size.height - 34;
    final step = size.width / items.length;
    final maxCount = items.fold<int>(
      0,
      (max, item) => item.count > max ? item.count : max,
    );
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

    for (var index = 0; index < items.length; index += 1) {
      final item = items[index];
      final centerX = (step * index) + (step / 2);
      final height = maxCount == 0
          ? 0.0
          : (item.count / maxCount) * (usableHeight - 20);
      final rect = RRect.fromRectAndCorners(
        Rect.fromLTWH(
          centerX - (barWidth / 2),
          baseline - height,
          barWidth,
          height,
        ),
        topLeft: const Radius.circular(6),
        topRight: const Radius.circular(6),
        bottomLeft: const Radius.circular(4),
        bottomRight: const Radius.circular(4),
      );
      canvas.drawRRect(
        rect,
        Paint()
          ..color = item.count == maxCount && maxCount > 0
              ? const Color(0xFF988B7B)
              : const Color(0xFFB9B0A5),
      );
      drawCentered(
        '${item.percent}%',
        Offset(centerX, baseline - height - 14),
        adminBodyStyle(size: 9),
      );
      drawCentered(
        item.label,
        Offset(centerX, baseline + 9),
        adminLightStyle(size: 8),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _AgeChartPainter oldDelegate) {
    return oldDelegate.items != items;
  }
}

import 'package:flutter/material.dart';

import '../../../app/app_routes.dart';
import '../../../app/dependencies_scope.dart';
import '../../../app/whynot_theme.dart';
import '../domain/recommended_product_saves.dart';
import 'widgets/admin_components.dart';

class RecommendedProductsScreen extends StatelessWidget {
  const RecommendedProductsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<RecommendedProductSaves>(
      stream: context.dependencies.adminMetricsController
          .watchRecommendedProductSaves(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _page(
            const Text('Could not load the recommended-products metric.'),
          );
        }

        if (!snapshot.hasData) {
          return _page(const Center(child: CircularProgressIndicator()));
        }

        return _page(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AdminSegmentedControl(
                labels: const ['Saved products', 'Recommended'],
                selectedIndex: 1,
                onSelected: (index) {
                  if (index == 0) {
                    Navigator.pushReplacementNamed(
                      context,
                      AppRoutes.adminSavedProducts,
                    );
                  }
                },
              ),
              const SizedBox(height: 18),
              RecommendedProductsMetricCard(total: snapshot.requireData.total),
              const SizedBox(height: 18),
              Text(
                'About this metric',
                style: WhyNotTextStyles.serif(size: 18, color: adminInk),
              ),
              const SizedBox(height: 8),
              Text(
                'This value only counts products saved through the '
                'recommendation feature. Manual product saves are not included.',
                style: adminLightStyle(size: 11),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _page(Widget content) => AdminPage(
    title: 'Recommended products',
    subtitle: 'How many recommended products have been saved?',
    currentRoute: AppRoutes.adminRecommendedProducts,
    children: [const SizedBox(height: 13), content],
  );
}

class RecommendedProductsMetricCard extends StatelessWidget {
  const RecommendedProductsMetricCard({required this.total, super.key});

  final int total;

  @override
  Widget build(BuildContext context) {
    return AdminSurface(
      height: 86,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('RECOMMENDED PRODUCTS SAVED', style: adminMetaStyle(size: 9)),
          const Spacer(),
          Text(
            '$total',
            style: WhyNotTextStyles.serif(size: 24, color: adminInk),
          ),
          Text('total successful saves', style: adminLightStyle(size: 9)),
        ],
      ),
    );
  }
}

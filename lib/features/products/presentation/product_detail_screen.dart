import 'package:flutter/material.dart';

import '../../../app/whynot_theme.dart';
import '../../../shared/widgets/app_bottom_navigation.dart';
import '../../../app/app_routes.dart';

class ProductDetailScreen extends StatelessWidget {
  const ProductDetailScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final arguments =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;

    final name =
        arguments?['name'] as String? ?? 'Product name';

    final store =
        arguments?['store'] as String? ?? 'Product Store';

    final originalPrice =
        arguments?['originalPrice'] as String? ?? r'$100';

    final currentPrice =
        arguments?['currentPrice'] as String? ?? r'$50';

    final sourceTab =
        arguments?['sourceTab'] as int? ?? 1;

    return Scaffold(
      backgroundColor: WhyNotColors.background,
      extendBody: true,
      body: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(32, 47, 32, 135),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: WhyNotTextStyles.serif(size: 30),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          store,
                          style: WhyNotTextStyles.muted(size: 15),
                        ),
                      ],
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () {},
                    style: TextButton.styleFrom(
                      foregroundColor: WhyNotColors.muted,
                      padding: const EdgeInsets.only(top: 4),
                      minimumSize: Size.zero,
                      tapTargetSize:
                          MaterialTapTargetSize.shrinkWrap,
                    ),
                    icon: const Icon(
                      Icons.check_circle_outline,
                      size: 18,
                      color: WhyNotColors.muted,
                    ),
                    label: const Text(
                      'Purchased',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 15,
                        fontWeight: FontWeight.w300,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 32),

              Container(
                width: double.infinity,
                height: 360,
                decoration: BoxDecoration(
                  color: WhyNotColors.card,
                  borderRadius: BorderRadius.circular(18),
                ),
              ),

              const SizedBox(height: 20),

              Row(
                children: [
                  Text(
                    originalPrice,
                    style: WhyNotTextStyles.muted(size: 15).copyWith(
                      decoration: TextDecoration.lineThrough,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    currentPrice,
                    style: WhyNotTextStyles.muted(size: 15),
                  ),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: () {
                      Navigator.pushReplacementNamed(
                        context,
                        AppRoutes.editProduct,
                        arguments: {
                          'name': name,
                          'store': store,
                          'originalPrice': originalPrice,
                          'currentPrice': currentPrice,
                          'wishlist': arguments?['wishlist'],
                          'sourceTab': sourceTab,
                        },
                      );
                    },
                    style: TextButton.styleFrom(
                      foregroundColor: WhyNotColors.muted,
                      padding: EdgeInsets.zero,
                      minimumSize: Size.zero,
                      tapTargetSize:
                          MaterialTapTargetSize.shrinkWrap,
                    ),
                    icon: const Icon(
                      Icons.edit_outlined,
                      size: 15,
                      color: WhyNotColors.muted,
                    ),
                    label: const Text(
                      'Edit item',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 15,
                        fontWeight: FontWeight.w300,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: AppBottomNavigation(
        selectedIndex: sourceTab,
      ),
    );
  }
}
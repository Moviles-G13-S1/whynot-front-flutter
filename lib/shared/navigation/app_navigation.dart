import 'package:flutter/material.dart';

import '../../app/app_routes.dart';
import '../../app/whynot_theme.dart';

/// Centralized navigation for the main application tabs.
abstract final class AppNavigation {
  static void select(
    BuildContext context,
    int index, {
    required int currentIndex,
  }) {
    switch (index) {
      case 0:
        Navigator.pushReplacementNamed(context, AppRoutes.home);
        return;

      case 1:
        Navigator.pushReplacementNamed(context, AppRoutes.wishlists);
        return;

      case 2:
        _showAddSheet(context);
        return;

      case 3:
        Navigator.pushReplacementNamed(context, AppRoutes.purchases);
        return;

      case 4:
        Navigator.pushReplacementNamed(context, AppRoutes.profile);
        return;
    }
  }

  static void _showAddSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: WhyNotColors.background,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 4, 24, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Add a new item', style: WhyNotTextStyles.serif(size: 26)),
              const SizedBox(height: 8),
              const Text(
                'Save something you love to one of your wishlists.',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  color: WhyNotColors.muted,
                  fontSize: 14,
                  fontWeight: FontWeight.w300,
                ),
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () {
                  Navigator.pop(sheetContext);

                  Navigator.pushNamed(context, AppRoutes.newProduct);
                },
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.black,
                  minimumSize: const Size.fromHeight(48),
                ),
                child: const Text('Continue'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

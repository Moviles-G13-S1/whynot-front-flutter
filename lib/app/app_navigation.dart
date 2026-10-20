import 'package:flutter/material.dart';

import '../views/widgets/add_item_sheet.dart';
import 'app_routes.dart';
import 'whynot_theme.dart';

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
      builder: (sheetContext) => AddItemSheet(
        onContinue: () {
          Navigator.pop(sheetContext);
          Navigator.pushNamed(context, AppRoutes.newProduct);
        },
      ),
    );
  }
}

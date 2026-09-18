import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../app/whynot_theme.dart';
import '../navigation/app_navigation.dart';

/// Five-item navigation bar shared by the main application screens.
class AppBottomNavigation extends StatelessWidget {
  const AppBottomNavigation({
    required this.selectedIndex,
    this.onSelected,
    super.key,
  });

  final int selectedIndex;
  final ValueChanged<int>? onSelected;

  static const _items = [
    _NavigationData('Home', 'assets/figma/home.svg'),
    _NavigationData('Wishlists', 'assets/figma/wishlist.svg'),
    _NavigationData('Add', ''),
    _NavigationData('Purchases', 'assets/figma/purchases.svg'),
    _NavigationData('Profile', 'assets/figma/profile.svg'),
  ];

  void _handleSelection(BuildContext context, int index) {
    if (onSelected != null) {
      onSelected!(index);
      return;
    }

    AppNavigation.select(
      context,
      index,
      currentIndex: selectedIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.paddingOf(context).bottom;

    return Container(
      height: 92 + bottomPadding,
      padding: EdgeInsets.fromLTRB(14, 7, 14, bottomPadding),
      decoration: const BoxDecoration(
        color: Color(0xF9FEFDFB),
        border: Border(top: BorderSide(color: WhyNotColors.divider)),
        boxShadow: [
          BoxShadow(
            color: Color(0x18000000),
            blurRadius: 5,
            offset: Offset(0, -1),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: List.generate(_items.length, (index) {
          if (index == 2) {
            return Expanded(
          child: _AddItem(
            onTap: () => _handleSelection(context, index),
          ),
          );
          }

          return Expanded(
            child: _NavigationItem(
              data: _items[index],
              isSelected: selectedIndex == index,
              onTap: () => _handleSelection(context, index),
            ),
          );
        }),
      ),
    );
  }
}

/// Immutable display data for a navigation destination.
class _NavigationData {
  const _NavigationData(this.label, this.asset);

  final String label;
  final String asset;
}

/// Standard navigation destination with an SVG icon.
class _NavigationItem extends StatelessWidget {
  const _NavigationItem({
    required this.data,
    required this.isSelected,
    required this.onTap,
  });

  final _NavigationData data;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: isSelected,
      button: true,
      label: data.label,
      child: InkResponse(
        onTap: onTap,
        radius: 28,
        child: SizedBox(
          width: double.infinity,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SvgPicture.asset(
                data.asset,
                width: 28,
                height: 29,
                colorFilter: isSelected
                    ? const ColorFilter.mode(Colors.black, BlendMode.srcIn)
                    : null,
              ),
              const SizedBox(height: 6),
              Text(
                data.label,
                maxLines: 1,
                style: TextStyle(
                  fontFamily: 'Poppins',
                  color: isSelected ? Colors.black : WhyNotColors.muted,
                  fontSize: 10,
                  fontWeight: isSelected ? FontWeight.w500 : FontWeight.w300,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Central add action, which has a different visual treatment.
class _AddItem extends StatelessWidget {
  const _AddItem({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Add',
      child: InkResponse(
        onTap: onTap,
        radius: 34,
        child: SizedBox(
          width: double.infinity,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: 42,
                height: 42,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SvgPicture.asset(
                      'assets/figma/add_circle.svg',
                      width: 42,
                      height: 42,
                    ),
                    SvgPicture.asset(
                      'assets/figma/add.svg',
                      width: 16,
                      height: 16,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 2),
              Text('Add', style: WhyNotTextStyles.muted(size: 10)),
            ],
          ),
        ),
      ),
    );
  }
}

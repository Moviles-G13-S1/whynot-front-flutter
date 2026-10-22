
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../app/app_routes.dart';
import '../../app/dependencies_scope.dart';
import '../../app/whynot_theme.dart';
import '../../app/app_navigation.dart';

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

    AppNavigation.select(context, index, currentIndex: selectedIndex);
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
            return const Expanded(
              child: _AddItem(),
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

/// Central button for adding a new product.
class _AddItem extends StatefulWidget {
  const _AddItem();

  @override
  State<_AddItem> createState() => _AddItemState();
}

class _AddItemState extends State<_AddItem> {
  bool _isCheckingWishlists = false;

  Future<void> _handleAdd() async {
    if (_isCheckingWishlists) return;

    setState(() => _isCheckingWishlists = true);

    try {
      final wishlistController = context.dependencies.wishlistController;

      if (wishlistController.currentUserId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please log in before adding products.'),
          ),
        );
        return;
      }

      final wishlists = await wishlistController.getCurrentSummaries();

      if (!mounted) return;

      // User already has a wishlist: open the product form.
      if (wishlists.isNotEmpty) {
        Navigator.pushNamed(context, AppRoutes.newProductManual);
        return;
      }

      // User has no wishlists: show a message first.
            
      final createWishlist = await showDialog<bool>(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            backgroundColor: WhyNotColors.background,
            surfaceTintColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
              side: const BorderSide(color: WhyNotColors.border),
            ),
            title: Text(
              'Create a wishlist first',
              style: WhyNotTextStyles.serif(size: 24),
            ),
            content: Text(
              'You need at least one wishlist before adding products.',
              style: WhyNotTextStyles.muted(size: 14),
            ),
            actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(dialogContext, false);
                },
                style: linkButtonStyle(),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(dialogContext, true);
                },
                style: linkButtonStyle(),
                child: const Text('Create Wishlist'),
              ),
            ],
          );
        },
      );


      if (!mounted) return;

      if (createWishlist == true) {
        Navigator.pushNamed(context, AppRoutes.newWishlist);
      }
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not load your wishlists. Please try again.'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isCheckingWishlists = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Add',
      child: InkResponse(
        onTap: _isCheckingWishlists ? null : _handleAdd,
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

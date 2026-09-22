import 'package:flutter/material.dart';

import '../../../../app/app_routes.dart';
import '../../../../app/dependencies_scope.dart';
import '../../../../app/whynot_theme.dart';

const adminInk = Color(0xFF252320);
const adminMuted = Color(0xFF736E66);
const adminSurface = Color(0xFFF4EFE8);
const adminPill = Color(0xFFF0E8DB);
const adminDivider = Color(0xFFD6CFC2);
const adminBar = Color(0xFF817D78);

TextStyle adminMetaStyle({double size = 10}) {
  return const TextStyle(
    fontFamily: 'Poppins',
    color: adminMuted,
    fontWeight: FontWeight.w400,
    letterSpacing: 0,
    height: 1.2,
  ).copyWith(fontSize: size);
}

TextStyle adminLightStyle({double size = 10, Color color = adminMuted}) {
  return TextStyle(
    fontFamily: 'Poppins',
    color: color,
    fontSize: size,
    fontWeight: FontWeight.w300,
    height: 1.2,
  );
}

TextStyle adminBodyStyle({double size = 10, Color color = adminInk}) {
  return TextStyle(
    fontFamily: 'Poppins',
    color: color,
    fontSize: size,
    fontWeight: FontWeight.w400,
    height: 1.2,
  );
}

class AdminPage extends StatelessWidget {
  const AdminPage({
    required this.title,
    required this.subtitle,
    required this.currentRoute,
    required this.children,
    this.titleSize = 28,
    this.padding = const EdgeInsets.fromLTRB(24, 19, 24, 36),
    super.key,
  });

  final String title;
  final String subtitle;
  final String currentRoute;
  final List<Widget> children;
  final double titleSize;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: padding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AdminHeader(
                title: title,
                subtitle: subtitle,
                currentRoute: currentRoute,
                titleSize: titleSize,
              ),
              ...children,
            ],
          ),
        ),
      ),
    );
  }
}

class AdminHeader extends StatelessWidget {
  const AdminHeader({
    required this.title,
    required this.subtitle,
    required this.currentRoute,
    this.titleSize = 28,
    super.key,
  });

  final String title;
  final String subtitle;
  final String currentRoute;
  final double titleSize;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('WHYNOT ADMIN', style: adminMetaStyle(size: 10)),
              const SizedBox(height: 7),
              Text(
                title,
                style: WhyNotTextStyles.serif(size: titleSize, color: adminInk),
              ),
              const SizedBox(height: 6),
              Text(subtitle, style: adminLightStyle(size: 12)),
            ],
          ),
        ),
        AdminMenuButton(
          onPressed: () => showAdminNavigation(context, currentRoute),
        ),
      ],
    );
  }
}

class AdminMenuButton extends StatelessWidget {
  const AdminMenuButton({required this.onPressed, super.key});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: 36,
      child: IconButton(
        onPressed: onPressed,
        style: IconButton.styleFrom(
          backgroundColor: adminPill,
          shape: const CircleBorder(),
          padding: EdgeInsets.zero,
        ),
        icon: const Icon(Icons.menu_rounded, size: 21, color: adminInk),
        tooltip: 'Open admin navigation',
      ),
    );
  }
}

class AdminSurface extends StatelessWidget {
  const AdminSurface({
    required this.child,
    this.height,
    this.padding = EdgeInsets.zero,
    this.radius = 16,
    super.key,
  });

  final Widget child;
  final double? height;
  final EdgeInsetsGeometry padding;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      padding: padding,
      decoration: BoxDecoration(
        color: adminSurface,
        borderRadius: BorderRadius.circular(radius),
      ),
      child: child,
    );
  }
}

class AdminSegmentedControl extends StatelessWidget {
  const AdminSegmentedControl({
    required this.labels,
    required this.selectedIndex,
    this.onSelected,
    this.height = 38,
    super.key,
  });

  final List<String> labels;
  final int selectedIndex;
  final ValueChanged<int>? onSelected;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: const Color(0xFFF0EBE3),
        borderRadius: BorderRadius.circular(height / 2),
      ),
      child: Row(
        children: List.generate(labels.length, (index) {
          final selected = index == selectedIndex;

          return Expanded(
            child: InkWell(
              borderRadius: BorderRadius.circular((height - 6) / 2),
              onTap: onSelected == null ? null : () => onSelected!(index),
              child: Container(
                height: height - 6,
                alignment: Alignment.center,
                margin: EdgeInsets.only(
                  left: index == 0 ? 3 : 0,
                  right: index == labels.length - 1 ? 3 : 0,
                ),
                decoration: selected
                    ? BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular((height - 6) / 2),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x12000000),
                            blurRadius: 4,
                            offset: Offset(0, 1),
                          ),
                        ],
                      )
                    : null,
                child: Text(
                  labels[index],
                  textAlign: TextAlign.center,
                  style: adminBodyStyle(
                    size: 11,
                    color: selected ? adminInk : adminMuted,
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

void showAdminNavigation(BuildContext context, String currentRoute) {
  showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Close admin navigation',
    barrierColor: const Color(0x59141312),
    transitionDuration: const Duration(milliseconds: 180),
    pageBuilder: (dialogContext, animation, secondaryAnimation) {
      return Align(
        alignment: Alignment.centerLeft,
        child: AdminNavigationPanel(currentRoute: currentRoute),
      );
    },
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      return SlideTransition(
        position: Tween<Offset>(begin: const Offset(-1, 0), end: Offset.zero)
            .animate(
              CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
            ),
        child: child,
      );
    },
  );
}

class AdminNavigationPanel extends StatelessWidget {
  const AdminNavigationPanel({required this.currentRoute, super.key});

  final String currentRoute;

  static const _items = [
    _AdminNavItem(
      title: 'Saved products',
      subtitle: 'Distribution per user',
      route: AppRoutes.adminSavedProducts,
    ),
    _AdminNavItem(
      title: 'Save methods',
      subtitle: 'Automatic vs. manual',
      route: AppRoutes.adminSaveMethods,
    ),
    _AdminNavItem(
      title: 'Purchased products',
      subtitle: 'Monthly by category',
      route: AppRoutes.adminPurchasedProducts,
    ),
    _AdminNavItem(
      title: 'Demographic profile',
      subtitle: 'Age, gender & city',
      route: AppRoutes.adminDemographicProfile,
    ),
  ];

  Future<void> _signOut(BuildContext context) async {
    await context.dependencies.authController.signOut();

    if (!context.mounted) return;

    Navigator.pushNamedAndRemoveUntil(
      context,
      AppRoutes.login,
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        width: 318,
        height: double.infinity,
        padding: const EdgeInsets.fromLTRB(24, 72, 24, 24),
        decoration: const BoxDecoration(
          color: WhyNotColors.background,
          borderRadius: BorderRadius.only(
            topRight: Radius.circular(28),
            bottomRight: Radius.circular(28),
          ),
        ),
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
                      Text('WHYNOT ADMIN', style: adminMetaStyle(size: 10)),
                      const SizedBox(height: 8),
                      Text(
                        'Metrics',
                        style: WhyNotTextStyles.serif(
                          size: 30,
                          color: adminInk,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Navigate between dashboard views',
                        style: adminLightStyle(size: 11),
                      ),
                    ],
                  ),
                ),
                SizedBox.square(
                  dimension: 36,
                  child: IconButton(
                    onPressed: () => Navigator.pop(context),
                    style: IconButton.styleFrom(
                      backgroundColor: adminPill,
                      shape: const CircleBorder(),
                      padding: EdgeInsets.zero,
                    ),
                    icon: const Icon(
                      Icons.arrow_back_rounded,
                      color: adminInk,
                      size: 22,
                    ),
                    tooltip: 'Close admin navigation',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 27),
            const Divider(height: 1, color: adminDivider),
            const SizedBox(height: 23),
            Text('METRICS', style: adminMetaStyle(size: 10)),
            const SizedBox(height: 10),
            for (final item in _items) ...[
              _AdminNavigationTile(
                item: item,
                selected: item.route == currentRoute,
              ),
              const SizedBox(height: 12),
            ],
            const Spacer(),
            TextButton.icon(
              onPressed: () => _signOut(context),
              icon: const Icon(Icons.logout_rounded, size: 18),
              label: const Text('Sign out'),
            ),
          ],
        ),
      ),
    );
  }
}

class _AdminNavigationTile extends StatelessWidget {
  const _AdminNavigationTile({required this.item, required this.selected});

  final _AdminNavItem item;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () {
        Navigator.pop(context);
        if (!selected) {
          Navigator.pushReplacementNamed(context, item.route);
        }
      },
      child: Container(
        height: 64,
        padding: const EdgeInsets.fromLTRB(14, 11, 13, 11),
        decoration: BoxDecoration(
          color: const Color(0xFFF6F2EC),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: const BoxDecoration(
                color: adminBar,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(item.title, style: adminBodyStyle(size: 12)),
                  const SizedBox(height: 5),
                  Text(item.subtitle, style: adminLightStyle(size: 10)),
                ],
              ),
            ),
            const Text(
              '›',
              style: TextStyle(
                fontFamily: 'Poppins',
                color: adminInk,
                fontSize: 20,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AdminNavItem {
  const _AdminNavItem({
    required this.title,
    required this.subtitle,
    required this.route,
  });

  final String title;
  final String subtitle;
  final String route;
}

import 'package:flutter/material.dart';

import '../../../app/app_routes.dart';
import '../../../app/whynot_theme.dart';
import '../../../shared/widgets/app_bottom_navigation.dart';

class NewProductScreen extends StatefulWidget {
  const NewProductScreen({super.key});

  @override
  State<NewProductScreen> createState() => _NewProductScreenState();
}

class _NewProductScreenState extends State<NewProductScreen> {
  final _linkController = TextEditingController();

  String? _selectedWishlist;

  static const _wishlists = [
    'Beauty',
    'Clothes',
    'Tech',
  ];

  @override
  void dispose() {
    _linkController.dispose();
    super.dispose();
  }

  void _saveItem() {
    if (_selectedWishlist == null) return;

    Navigator.pushReplacementNamed(
      context,
      AppRoutes.wishlistDetail,
      arguments: {
        'categoryName': _selectedWishlist,
        'itemCount': 1,
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: WhyNotColors.background,
      extendBody: true,
      body: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(24, 40, 24, 130),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Why Not?',
                style: WhyNotTextStyles.serif(size: 30),
              ),

              const SizedBox(height: 10),

              Text(
                'Paste a link and we’ll do the rest.',
                style: WhyNotTextStyles.muted(size: 15),
              ),

              const SizedBox(height: 26),

              TextField(
                controller: _linkController,
                keyboardType: TextInputType.url,
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 15,
                  fontWeight: FontWeight.w300,
                ),
                decoration: InputDecoration(
                  hintText: 'http://www.somestore.com',
                  hintStyle: WhyNotTextStyles.muted(size: 15),
                  prefixIcon: const Icon(
                    Icons.link,
                    size: 20,
                    color: WhyNotColors.muted,
                  ),
                  filled: true,
                  fillColor: WhyNotColors.field,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(18),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(18),
                    borderSide: const BorderSide(
                      color: WhyNotColors.border,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(18),
                    borderSide: const BorderSide(
                      color: WhyNotColors.muted,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 28),

              Text(
                'Or, add manually',
                style: WhyNotTextStyles.muted(size: 15),
              ),

              const SizedBox(height: 12),

              Center(
                child: TextButton(
                  onPressed: () {
                    Navigator.pushNamed(
                      context,
                      AppRoutes.newProductManual,
                    );
                  },
                  child: const Text(
                    'Add manually',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 15,
                      fontWeight: FontWeight.w300,
                      color: WhyNotColors.muted,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 24),

              Text(
                'Save to:',
                style: WhyNotTextStyles.muted(size: 15),
              ),

              const SizedBox(height: 18),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: _wishlists.map((wishlist) {
                  final selected = _selectedWishlist == wishlist;

                  return InkWell(
                    onTap: () {
                      setState(() {
                        _selectedWishlist = wishlist;
                      });
                    },
                    borderRadius: BorderRadius.circular(18),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 8,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            selected
                                ? Icons.check_circle
                                : Icons.circle_outlined,
                            size: 18,
                            color: selected
                                ? Colors.black
                                : WhyNotColors.muted,
                          ),
                          const SizedBox(width: 7),
                          Text(
                            wishlist,
                            style: WhyNotTextStyles.muted(size: 15),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),

              const SizedBox(height: 42),

              SizedBox(
                width: double.infinity,
                height: 44,
                child: FilledButton(
                  onPressed:
                      _selectedWishlist == null ? null : _saveItem,
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.black,
                    disabledBackgroundColor:
                        Colors.black.withValues(alpha: 0.25),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                  ),
                  child: const Text(
                    'Save Item',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 15,
                      fontWeight: FontWeight.w300,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: const AppBottomNavigation(
        selectedIndex: 2,
      ),
    );
  }
}
import 'package:flutter/material.dart';

import '../../../app/app_routes.dart';
import '../../../app/whynot_theme.dart';
import '../../../shared/widgets/app_bottom_navigation.dart';
import '../../../shared/widgets/form_controls.dart';

class NewWishlistScreen extends StatefulWidget {
  const NewWishlistScreen({super.key});

  @override
  State<NewWishlistScreen> createState() => _NewWishlistScreenState();
}

class _NewWishlistScreenState extends State<NewWishlistScreen> {
  static const List<String> _categories = [
    'Beauty',
    'Clothes',
    'Tech',
  ];

  String? _selectedCategory;

  void _saveWishlist() {
    if (_selectedCategory == null) return;

    Navigator.pushReplacementNamed(
      context,
      AppRoutes.wishlistDetail,
      arguments: {
        'categoryName': _selectedCategory,
        'itemCount': 0,
      },
    );
  }

  void _cancel() {
    Navigator.pushReplacementNamed(
      context,
      AppRoutes.wishlists,
    );
  }

  void _selectPicture() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Picture upload coming soon'),
      ),
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
                'New Wishlist',
                style: WhyNotTextStyles.serif(size: 30),
              ),

              const SizedBox(height: 58),

              const FieldLabel('Category'),

              const SizedBox(height: 14),

              DesignDropdown(
                value: _selectedCategory,
                items: _categories,
                onChanged: (value) {
                  setState(() {
                    _selectedCategory = value;
                  });
                },
              ),

              const SizedBox(height: 35),

              const FieldLabel('Picture'),

              const SizedBox(height: 14),

              InkWell(
                onTap: _selectPicture,
                borderRadius: BorderRadius.circular(18),
                child: Container(
                  width: double.infinity,
                  height: 70,
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  decoration: BoxDecoration(
                    color: WhyNotColors.field,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: WhyNotColors.border,
                    ),
                  ),
                  child: Row(
                    children: [
                      Text(
                        'Upload picture',
                        style: WhyNotTextStyles.muted(size: 14),
                      ),
                      const Spacer(),
                      const Icon(
                        Icons.file_upload_outlined,
                        size: 24,
                        color: WhyNotColors.muted,
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 42),

              Row(
                children: [
                  TextButton(
                    onPressed: _cancel,
                    style: TextButton.styleFrom(
                      foregroundColor: WhyNotColors.muted,
                      padding: EdgeInsets.zero,
                    ),
                    child: const Text(
                      'Cancel',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 15,
                        fontWeight: FontWeight.w300,
                      ),
                    ),
                  ),

                  const Spacer(),

                  TextButton(
                    onPressed:
                        _selectedCategory == null ? null : _saveWishlist,
                    style: TextButton.styleFrom(
                      foregroundColor: WhyNotColors.muted,
                      disabledForegroundColor:
                          WhyNotColors.muted.withValues(alpha: 0.35),
                      padding: EdgeInsets.zero,
                    ),
                    child: const Text(
                      'Save',
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
      bottomNavigationBar: const AppBottomNavigation(
        selectedIndex: 1,
      ),
    );
  }
}
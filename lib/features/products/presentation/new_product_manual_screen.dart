import 'package:flutter/material.dart';

import '../../../app/app_routes.dart';
import '../../../app/whynot_theme.dart';
import '../../../shared/widgets/app_bottom_navigation.dart';

class NewProductManualScreen extends StatefulWidget {
  const NewProductManualScreen({super.key});

  @override
  State<NewProductManualScreen> createState() =>
      _NewProductManualScreenState();
}

class _NewProductManualScreenState extends State<NewProductManualScreen> {
  final _nameController = TextEditingController();

  String? _selectedWishlist;

  static const _wishlists = [
    'Beauty',
    'Clothes',
    'Tech',
  ];

  @override
  void initState() {
    super.initState();

    _nameController.addListener(() {
      setState(() {});
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  bool get _canSave =>
      _nameController.text.trim().isNotEmpty &&
      _selectedWishlist != null;

  void _selectPicture() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Picture upload coming soon'),
      ),
    );
  }

  void _saveItem() {
    if (!_canSave) return;

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
                'New Product',
                style: WhyNotTextStyles.serif(size: 30),
              ),

              const SizedBox(height: 58),

              Text(
                'Name',
                style: WhyNotTextStyles.serif(size: 20),
              ),

              const SizedBox(height: 14),

              SizedBox(
                height: 42,
                child: TextField(
                  controller: _nameController,
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 14,
                    fontWeight: FontWeight.w300,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Product name',
                    hintStyle: WhyNotTextStyles.muted(size: 14),
                    filled: true,
                    fillColor: WhyNotColors.field,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
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
              ),

              const SizedBox(height: 35),

              Text(
                'Picture',
                style: WhyNotTextStyles.serif(size: 20),
              ),

              const SizedBox(height: 14),

              InkWell(
                onTap: _selectPicture,
                borderRadius: BorderRadius.circular(18),
                child: Container(
                  height: 58,
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                  ),
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

              const SizedBox(height: 36),

              Text(
                'Save to:',
                style: WhyNotTextStyles.muted(size: 15),
              ),

              const SizedBox(height: 18),

              Row(
                mainAxisAlignment:
                    MainAxisAlignment.spaceBetween,
                children: _wishlists.map((wishlist) {
                  final selected =
                      _selectedWishlist == wishlist;

                  return InkWell(
                    onTap: () {
                      setState(() {
                        _selectedWishlist = wishlist;
                      });
                    },
                    borderRadius: BorderRadius.circular(18),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
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
                          const SizedBox(width: 6),
                          Text(
                            wishlist,
                            style:
                                WhyNotTextStyles.muted(size: 15),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),

              const SizedBox(height: 44),

              SizedBox(
                width: double.infinity,
                height: 44,
                child: FilledButton(
                  onPressed: _canSave ? _saveItem : null,
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.black,
                    disabledBackgroundColor:
                        Colors.black.withValues(alpha: 0.25),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(24),
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
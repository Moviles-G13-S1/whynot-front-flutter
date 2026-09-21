import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
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
  final _imageUrlController = TextEditingController();

  final Map<String, String> _categoryIdsByName = {};

  List<String> _categories = [];
  String? _selectedCategory;

  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  @override
  void dispose() {
    _imageUrlController.dispose();
    super.dispose();
  }

  /// Loads the approved categories from Firestore and removes
  /// categories already used by the current user's wishlists.
  Future<void> _loadCategories() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
      return;
    }

    try {
      final categoriesSnapshot =
          await FirebaseFirestore.instance.collection('categories').get();

      final wishlistsSnapshot = await FirebaseFirestore.instance
          .collection('wishlists')
          .where('ownerId', isEqualTo: user.uid)
          .get();

      final usedCategoryIds = wishlistsSnapshot.docs
          .map((doc) => doc.data()['categoryId'] as String?)
          .whereType<String>()
          .toSet();

      final availableCategories = <String>[];

      for (final document in categoriesSnapshot.docs) {
        if (usedCategoryIds.contains(document.id)) {
          continue;
        }

        final data = document.data();
        final name = data['name'] as String?;

        if (name == null) {
          continue;
        }

        _categoryIdsByName[name] = document.id;
        availableCategories.add(name);
      }

      availableCategories.sort();

      if (!mounted) return;

      setState(() {
        _categories = availableCategories;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() => _isLoading = false);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not load categories.'),
        ),
      );
    }
  }

  Future<void> _saveWishlist() async {
    if (_selectedCategory == null || _isSaving) {
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    final categoryId = _categoryIdsByName[_selectedCategory];

    if (user == null || categoryId == null) {
      return;
    }

    setState(() => _isSaving = true);

    try {
      final wishlist =
          await FirebaseFirestore.instance.collection('wishlists').add({
        'ownerId': user.uid,
        'categoryId': categoryId,
        'imageUrl': _imageUrlController.text.trim(),
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;

      Navigator.pushReplacementNamed(
        context,
        AppRoutes.wishlistDetail,
        arguments: {
          'wishlistId': wishlist.id,
          'categoryId': categoryId,
          'categoryName': _selectedCategory,
          'itemCount': 0,
        },
      );
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not create wishlist. Please try again.'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  void _cancel() {
    Navigator.pushReplacementNamed(
      context,
      AppRoutes.wishlists,
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

              if (_isLoading)
                const Center(
                  child: CircularProgressIndicator(),
                )
              else if (_categories.isEmpty)
                Text(
                  'You already have a wishlist for every available category.',
                  style: WhyNotTextStyles.muted(size: 14),
                )
              else
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

              const FieldLabel('Picture link'),

              const SizedBox(height: 14),

              DesignField(
                controller: _imageUrlController,
                keyboardType: TextInputType.url,
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
                    onPressed: _selectedCategory == null || _isSaving
                        ? null
                        : _saveWishlist,
                    style: TextButton.styleFrom(
                      foregroundColor: WhyNotColors.muted,
                      disabledForegroundColor:
                          WhyNotColors.muted.withValues(alpha: 0.35),
                      padding: EdgeInsets.zero,
                    ),
                    child: Text(
                      _isSaving ? 'Saving...' : 'Save',
                      style: const TextStyle(
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
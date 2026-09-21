import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
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
  final _brandController = TextEditingController();
  final _priceController = TextEditingController();
  final _imageUrlController = TextEditingController();
  final _productUrlController = TextEditingController();

  final List<Map<String, String>> _wishlists = [];

  String? _selectedWishlistId;
  String? _selectedCategoryId;
  String? _selectedWishlistName;

  bool _initialized = false;
  bool _isLoadingWishlists = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();

    _nameController.addListener(_refresh);
    _brandController.addListener(_refresh);
    _priceController.addListener(_refresh);
    _imageUrlController.addListener(_refresh);
    _productUrlController.addListener(_refresh);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (_initialized) return;
    _initialized = true;

    final arguments =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;

    _selectedWishlistId = arguments?['wishlistId'] as String?;
    _selectedCategoryId = arguments?['categoryId'] as String?;
    _selectedWishlistName = arguments?['categoryName'] as String?;

    if (_selectedWishlistId == null) {
      _loadWishlists();
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _brandController.dispose();
    _priceController.dispose();
    _imageUrlController.dispose();
    _productUrlController.dispose();
    super.dispose();
  }

  void _refresh() {
    if (mounted) {
      setState(() {});
    }
  }

  bool get _canSave {
    final price = double.tryParse(
      _priceController.text.trim().replaceAll(',', '.'),
    );

    return _nameController.text.trim().isNotEmpty &&
        _brandController.text.trim().isNotEmpty &&
        price != null &&
        price >= 0 &&
        _selectedWishlistId != null &&
        _selectedCategoryId != null;
  }

  Future<void> _loadWishlists() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) return;

    setState(() => _isLoadingWishlists = true);

    try {
      final wishlistSnapshot = await FirebaseFirestore.instance
          .collection('wishlists')
          .where('ownerId', isEqualTo: user.uid)
          .get();

      final categorySnapshot =
          await FirebaseFirestore.instance.collection('categories').get();

      final categoryNames = {
        for (final document in categorySnapshot.docs)
          document.id: document.data()['name'] as String? ?? document.id,
      };

      final loadedWishlists = <Map<String, String>>[];

      for (final document in wishlistSnapshot.docs) {
        final data = document.data();
        final categoryId = data['categoryId'] as String?;

        if (categoryId == null) continue;

        loadedWishlists.add({
          'wishlistId': document.id,
          'categoryId': categoryId,
          'name': categoryNames[categoryId] ?? categoryId,
        });
      }

      loadedWishlists.sort(
        (a, b) => (a['name'] ?? '').compareTo(b['name'] ?? ''),
      );

      if (!mounted) return;

      setState(() {
        _wishlists
          ..clear()
          ..addAll(loadedWishlists);

        _isLoadingWishlists = false;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() => _isLoadingWishlists = false);

      _showMessage('Could not load your wishlists.');
    }
  }

  Future<void> _saveItem() async {
    if (!_canSave || _isSaving) return;

    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      _showMessage('No user logged in.');
      return;
    }

    final normalizedPrice =
        _priceController.text.trim().replaceAll(',', '.');

    final price = double.tryParse(normalizedPrice);

    if (price == null) {
      _showMessage('Please enter a valid price.');
      return;
    }

    setState(() => _isSaving = true);

    try {
      await FirebaseFirestore.instance.collection('products').add({
        'ownerId': user.uid,
        'wishlistId': _selectedWishlistId,
        'categoryId': _selectedCategoryId,
        'name': _nameController.text.trim(),
        'brand': _brandController.text.trim(),
        'price': price,
        'imageUrl': _imageUrlController.text.trim(),
        'productUrl': _productUrlController.text.trim(),

        // Every new product starts as not purchased.
        'purchased': false,

        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;

      Navigator.pushReplacementNamed(
        context,
        AppRoutes.wishlistDetail,
        arguments: {
          'wishlistId': _selectedWishlistId,
          'categoryId': _selectedCategoryId,
          'categoryName': _selectedWishlistName,
        },
      );
    } catch (_) {
      if (!mounted) return;

      _showMessage(
        'Could not save product. Please try again.',
      );
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
      ),
    );
  }

  Widget _label(String text) {
    return Text(
      text,
      style: WhyNotTextStyles.serif(size: 20),
    );
  }

  Widget _textField({
    required TextEditingController controller,
    required String hint,
    TextInputType? keyboardType,
  }) {
    return SizedBox(
      height: 42,
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        style: const TextStyle(
          fontFamily: 'Poppins',
          fontSize: 14,
          fontWeight: FontWeight.w300,
        ),
        decoration: InputDecoration(
          hintText: hint,
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
          padding: const EdgeInsets.fromLTRB(
            24,
            40,
            24,
            130,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'New Product',
                style: WhyNotTextStyles.serif(size: 30),
              ),

              const SizedBox(height: 42),

              _label('Name'),
              const SizedBox(height: 14),
              _textField(
                controller: _nameController,
                hint: 'Product name',
              ),

              const SizedBox(height: 30),

              _label('Brand'),
              const SizedBox(height: 14),
              _textField(
                controller: _brandController,
                hint: 'Brand name',
              ),

              const SizedBox(height: 30),

              _label('Price'),
              const SizedBox(height: 14),
              _textField(
                controller: _priceController,
                hint: 'Product price',
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
              ),

              const SizedBox(height: 30),

              _label('Picture link'),
              const SizedBox(height: 14),
              _textField(
                controller: _imageUrlController,
                hint: 'https://...',
                keyboardType: TextInputType.url,
              ),

              const SizedBox(height: 30),

              _label('Product link'),
              const SizedBox(height: 14),
              _textField(
                controller: _productUrlController,
                hint: 'https://...',
                keyboardType: TextInputType.url,
              ),

              const SizedBox(height: 36),

              Text(
                'Save to:',
                style: WhyNotTextStyles.muted(size: 15),
              ),

              const SizedBox(height: 18),

              if (_selectedWishlistId != null)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
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
                      const Icon(
                        Icons.check_circle,
                        size: 18,
                        color: Colors.black,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _selectedWishlistName ?? 'Wishlist',
                        style: WhyNotTextStyles.muted(size: 15),
                      ),
                    ],
                  ),
                )
              else if (_isLoadingWishlists)
                const Center(
                  child: CircularProgressIndicator(),
                )
              else if (_wishlists.isEmpty)
                Text(
                  'Create a wishlist before adding a product.',
                  style: WhyNotTextStyles.muted(size: 14),
                )
              else
                Column(
                  children: _wishlists.map((wishlist) {
                    final wishlistId = wishlist['wishlistId'];
                    final categoryId = wishlist['categoryId'];
                    final name = wishlist['name'];

                    final selected =
                        _selectedWishlistId == wishlistId;

                    return InkWell(
                      onTap: () {
                        setState(() {
                          _selectedWishlistId = wishlistId;
                          _selectedCategoryId = categoryId;
                          _selectedWishlistName = name;
                        });
                      },
                      borderRadius: BorderRadius.circular(18),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 10,
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
                            const SizedBox(width: 8),
                            Text(
                              name ?? 'Wishlist',
                              style: WhyNotTextStyles.muted(
                                size: 15,
                              ),
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
                  onPressed:
                      _canSave && !_isSaving ? _saveItem : null,
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.black,
                    disabledBackgroundColor:
                        Colors.black.withValues(alpha: 0.25),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                  ),
                  child: Text(
                    _isSaving ? 'Saving...' : 'Save Item',
                    style: const TextStyle(
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
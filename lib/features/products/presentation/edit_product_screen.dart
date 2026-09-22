import 'package:flutter/material.dart';

import '../../../app/dependencies_scope.dart';
import '../../../app/whynot_theme.dart';
import '../../../shared/widgets/app_bottom_navigation.dart';
import '../domain/product.dart';

class EditProductScreen extends StatefulWidget {
  const EditProductScreen({super.key});

  @override
  State<EditProductScreen> createState() => _EditProductScreenState();
}

class _EditProductScreenState extends State<EditProductScreen> {
  final _nameController = TextEditingController();
  final _brandController = TextEditingController();
  final _priceController = TextEditingController();
  final _imageUrlController = TextEditingController();
  final _productUrlController = TextEditingController();

  final List<Map<String, String>> _wishlists = [];

  String? _productId;

  String? _selectedWishlistId;
  String? _selectedCategoryId;
  bool _initialized = false;
  bool _isLoading = true;
  bool _isSaving = false;

  int _sourceTab = 1;

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

    _productId = arguments?['productId'] as String?;
    _sourceTab = arguments?['sourceTab'] as int? ?? 1;

    _loadData();
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

  Future<void> _loadData() async {
    if (context.dependencies.productController.currentUserId == null ||
        _productId == null) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
      return;
    }

    try {
      final productController = context.dependencies.productController;
      final product = await productController.get(_productId!);
      if (product == null) {
        if (!mounted) return;

        setState(() => _isLoading = false);
        _showMessage('Product not found.');
        return;
      }

      _nameController.text = product.name;
      _brandController.text = product.brand;
      _priceController.text = product.price % 1 == 0
          ? product.price.toInt().toString()
          : product.price.toString();
      _imageUrlController.text = product.imageUrl;
      _productUrlController.text = product.productUrl;
      _selectedWishlistId = product.wishlistId;
      _selectedCategoryId = product.categoryId;

      final summaries = await productController.getCurrentWishlists();
      final loadedWishlists = summaries.map((summary) {
        return {
          'wishlistId': summary.wishlist.id,
          'categoryId': summary.wishlist.categoryId,
          'name': summary.categoryName,
        };
      }).toList();

      if (!mounted) return;

      setState(() {
        _wishlists
          ..clear()
          ..addAll(loadedWishlists);

        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() => _isLoading = false);

      _showMessage('Could not load product.');
    }
  }

  Future<void> _saveChanges() async {
    if (!_canSave || _isSaving || _productId == null) {
      return;
    }

    FocusScope.of(context).unfocus();

    final normalizedPrice = _priceController.text.trim().replaceAll(',', '.');

    final price = double.tryParse(normalizedPrice);

    if (price == null) {
      _showMessage('Please enter a valid price.');
      return;
    }

    setState(() => _isSaving = true);

    try {
      await context.dependencies.productController.update(
        _productId!,
        ProductDraft(
          wishlistId: _selectedWishlistId!,
          categoryId: _selectedCategoryId!,
          name: _nameController.text.trim(),
          brand: _brandController.text.trim(),
          price: price,
          imageUrl: _imageUrlController.text.trim(),
          productUrl: _productUrlController.text.trim(),
        ),
      );

      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Product updated')));

      Navigator.pop(context);
    } catch (_) {
      if (!mounted) return;

      _showMessage('Could not update product. Please try again.');
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  void _cancel() {
    Navigator.pop(context);
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Widget _label(String text) {
    return Text(text, style: WhyNotTextStyles.serif(size: 20));
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
          contentPadding: const EdgeInsets.symmetric(horizontal: 14),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: const BorderSide(color: WhyNotColors.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: const BorderSide(color: WhyNotColors.muted),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_productId == null) {
      return Scaffold(
        body: Center(
          child: Text(
            'Product not found.',
            style: WhyNotTextStyles.muted(size: 14),
          ),
        ),
      );
    }

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
              Text('Edit Item', style: WhyNotTextStyles.serif(size: 30)),

              const SizedBox(height: 42),

              // Name
              _label('Name'),

              const SizedBox(height: 14),

              _textField(controller: _nameController, hint: 'Product name'),

              const SizedBox(height: 30),

              // Brand
              _label('Brand'),

              const SizedBox(height: 14),

              _textField(controller: _brandController, hint: 'Brand name'),

              const SizedBox(height: 30),

              // Price
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

              // Picture link
              _label('Picture link'),

              const SizedBox(height: 14),

              _textField(
                controller: _imageUrlController,
                hint: 'https://...',
                keyboardType: TextInputType.url,
              ),

              const SizedBox(height: 30),

              // Product link
              _label('Product link'),

              const SizedBox(height: 14),

              _textField(
                controller: _productUrlController,
                hint: 'https://...',
                keyboardType: TextInputType.url,
              ),

              const SizedBox(height: 36),

              Text('Save to:', style: WhyNotTextStyles.muted(size: 15)),

              const SizedBox(height: 18),

              if (_wishlists.isEmpty)
                Text(
                  'No wishlists available.',
                  style: WhyNotTextStyles.muted(size: 14),
                )
              else
                Column(
                  children: _wishlists.map((wishlist) {
                    final wishlistId = wishlist['wishlistId'];

                    final categoryId = wishlist['categoryId'];

                    final name = wishlist['name'];

                    final selected = _selectedWishlistId == wishlistId;

                    return InkWell(
                      onTap: () {
                        setState(() {
                          _selectedWishlistId = wishlistId;
                          _selectedCategoryId = categoryId;
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
                              style: WhyNotTextStyles.muted(size: 15),
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
                  onPressed: _canSave && !_isSaving ? _saveChanges : null,
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.black,
                    disabledBackgroundColor: Colors.black.withValues(
                      alpha: 0.25,
                    ),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                  ),
                  child: Text(
                    _isSaving ? 'Saving...' : 'Save Changes',
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 15,
                      fontWeight: FontWeight.w300,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 12),

              Center(
                child: TextButton(
                  onPressed: _cancel,
                  child: Text(
                    'Cancel',
                    style: WhyNotTextStyles.muted(size: 15),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: AppBottomNavigation(selectedIndex: _sourceTab),
    );
  }
}

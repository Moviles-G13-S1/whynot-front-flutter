import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../app/app_routes.dart';
import '../../../app/dependencies_scope.dart';
import '../../../app/whynot_theme.dart';
import '../../../shared/widgets/app_bottom_navigation.dart';
import '../../speech/application/speech_controller.dart';
import '../../speech/domain/speech_state.dart';
import '../../speech/presentation/voice_input_button.dart';
import '../domain/product.dart';

enum _VoiceField { name, brand }

class NewProductManualScreen extends StatefulWidget {
  const NewProductManualScreen({super.key});

  @override
  State<NewProductManualScreen> createState() => _NewProductManualScreenState();
}

class _NewProductManualScreenState extends State<NewProductManualScreen> {
  final _nameController = TextEditingController();
  final _brandController = TextEditingController();
  final _priceController = TextEditingController();
  final _imageUrlController = TextEditingController();
  final _productUrlController = TextEditingController();

  final List<Map<String, String>> _wishlists = [];

  SpeechController? _speechController;

  String? _selectedWishlistId;
  String? _selectedCategoryId;
  String? _selectedWishlistName;

  _VoiceField? _voiceTarget;
  String? _voiceError;

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

    _speechController ??= context.dependencies.speechController;

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
    final speechController = _speechController;

    if (speechController != null && speechController.isListening) {
      unawaited(speechController.cancelListening());
    }

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

  Future<void> _startVoiceInput(_VoiceField field) async {
    final speechController = _speechController;

    if (speechController == null ||
        speechController.isListening ||
        _isSaving) {
      return;
    }

    setState(() {
      _voiceTarget = field;
      _voiceError = null;
    });

    final recognition = speechController.startListening();

    // startListening changes the controller to Listening synchronously before
    // awaiting the platform recognizer. Rebuild so the microphone and helper
    // text immediately reflect that state.
    if (mounted) {
      setState(() {});
    }

    await recognition;

    if (!mounted) return;

    final state = speechController.state;

    if (state is SpeechResult) {
      final text = _capitalizeFirst(state.text.trim());

      if (text.isNotEmpty) {
        switch (field) {
          case _VoiceField.name:
            _nameController.text = text;
          case _VoiceField.brand:
            _brandController.text = text;
        }
      }
    } else if (state is SpeechFailure) {
      _voiceError = state.message;
    }

    speechController.reset();

    setState(() {
      _voiceTarget = null;
    });
  }

  String _capitalizeFirst(String value) {
    if (value.isEmpty) {
      return value;
    }

    if (value.length == 1) {
      return value.toUpperCase();
    }

    return '${value[0].toUpperCase()}${value.substring(1)}';
  }

  Future<void> _loadWishlists() async {
    if (context.dependencies.productController.currentUserId == null) return;

    setState(() => _isLoadingWishlists = true);

    try {
      final summaries = await context.dependencies.productController
          .getCurrentWishlists();

      final loadedWishlists = summaries
          .map(
            (summary) => {
              'wishlistId': summary.wishlist.id,
              'categoryId': summary.wishlist.categoryId,
              'name': summary.categoryName,
            },
          )
          .toList();

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

    if (context.dependencies.productController.currentUserId == null) {
      _showMessage('No user logged in.');
      return;
    }

    final normalizedPrice = _priceController.text.trim().replaceAll(',', '.');

    final price = double.tryParse(normalizedPrice);

    if (price == null) {
      _showMessage('Please enter a valid price.');
      return;
    }

    setState(() => _isSaving = true);

    try {
      await context.dependencies.productController.create(
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

      _showMessage('Could not save product. Please try again.');
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
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
    List<TextInputFormatter>? inputFormatters,
    Widget? suffixIcon,
  }) {
    return SizedBox(
      height: 42,
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        inputFormatters: inputFormatters,
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
          suffixIcon: suffixIcon,
          suffixIconConstraints: const BoxConstraints(
            minWidth: 42,
            minHeight: 42,
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

  Widget _listeningMessage(_VoiceField field) {
    final speechController = _speechController;

    if (speechController == null ||
        !speechController.isListening ||
        _voiceTarget != field) {
      return const SizedBox.shrink();
    }

    final fieldName = switch (field) {
      _VoiceField.name => 'name',
      _VoiceField.brand => 'brand',
    };

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          const Icon(
            Icons.graphic_eq,
            size: 16,
            color: WhyNotColors.muted,
          ),
          const SizedBox(width: 5),
          Text(
            'Listening… say the product $fieldName',
            style: WhyNotTextStyles.muted(size: 12),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final speechController = _speechController;

    final listening = speechController?.isListening ?? false;

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

              const SizedBox(height: 42),

              _label('Name'),

              const SizedBox(height: 14),

              _textField(
                controller: _nameController,
                hint: 'Product name',
                suffixIcon: VoiceInputButton(
                  enabled: !_isSaving,
                  isListening:
                      listening && _voiceTarget == _VoiceField.name,
                  onPressed: () {
                    _startVoiceInput(_VoiceField.name);
                  },
                ),
              ),

              _listeningMessage(_VoiceField.name),

              const SizedBox(height: 30),

              _label('Brand'),

              const SizedBox(height: 14),

              _textField(
                controller: _brandController,
                hint: 'Brand name',
                suffixIcon: VoiceInputButton(
                  enabled: !_isSaving,
                  isListening:
                      listening && _voiceTarget == _VoiceField.brand,
                  onPressed: () {
                    _startVoiceInput(_VoiceField.brand);
                  },
                ),
              ),

              _listeningMessage(_VoiceField.brand),

              if (_voiceError != null) ...[
                const SizedBox(height: 12),
                Text(
                  _voiceError!,
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 12,
                    fontWeight: FontWeight.w300,
                    color: Colors.redAccent,
                  ),
                ),
              ],

              const SizedBox(height: 30),

              _label('Price'),

              const SizedBox(height: 14),

              _textField(
                controller: _priceController,
                hint: 'Product price',
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: [
                  TextInputFormatter.withFunction(
                    (oldValue, newValue) {
                      final isValid = RegExp(
                        r'^\d*(?:[.,]\d*)?$',
                      ).hasMatch(newValue.text);

                      return isValid ? newValue : oldValue;
                    },
                  ),
                ],
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
                      _canSave && !_isSaving && !listening
                      ? _saveItem
                      : null,
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
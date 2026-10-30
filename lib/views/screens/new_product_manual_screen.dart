import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/app_routes.dart';
import '../../app/dependencies_scope.dart';
import '../../app/whynot_theme.dart';
import '../../controllers/connectivity_status.dart';
import '../widgets/connectivity_message.dart';
import '../widgets/app_bottom_navigation.dart';
import '../../models/product.dart';
import '../../models/input_policy.dart';

import '../../models/local_product_draft.dart';
import '../../infrastructure/repositories/sqlite_product_draft_store.dart';

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

  final List<Map<String, String?>> _wishlists = [];

  String? _selectedWishlistId;
  String? _selectedCategoryId;
  String? _selectedWishlistName;
  String? _selectedWishlistEmoji;

  bool _initialized = false;
  bool _isLoadingWishlists = false;
  bool _isSaving = false;
  bool _savedRemotely = false;

  // Juliana - Sprint 3: local draft caching and memory management.
  Timer? _draftDebounce;
  SqliteProductDraftStore? _draftStore;
  String? _draftUserId;
  // Juliana - Sprint 3: Eventual Connectivity.
  ConnectivityStatus? _connectivity;
  NetworkStatus _network = NetworkStatus.unknown;
  bool _connectionRestored = false;

  // Fixed when Add Item was opened inside a particular wishlist.
  // Null when opened using the black central + button.
  String? _originWishlistId;

  Future<void> _pendingDraftWrites = Future<void>.value();

  bool _restoringDraft = false;
  bool _hasEditedDraft = false;

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

    _connectivity = context.dependencies.connectivity;
    _network = _connectivity!.status;
    _connectivity!.addListener(_onConnectivityChanged);

    final arguments =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;

    _originWishlistId = arguments?['wishlistId'] as String?;
    _selectedWishlistId = _originWishlistId;
    _selectedCategoryId = arguments?['categoryId'] as String?;
    _selectedWishlistName = arguments?['categoryName'] as String?;
    _selectedWishlistEmoji = arguments?['emoji'] as String?;

    if (_selectedWishlistId == null) {
      _loadWishlists();
    }
    _draftStore = context.dependencies.productDraftStore;
    _draftUserId = context.dependencies.productController.currentUserId;

    if (_draftUserId != null) {
      unawaited(_restoreLocalDraft(_draftUserId!));
    }
  }

  void _onConnectivityChanged() {
    final status = _connectivity?.status ?? NetworkStatus.unknown;

    if (!mounted || status == _network) return;

    final wasOffline = _network == NetworkStatus.offline;

    setState(() {
      _network = status;

      if (status == NetworkStatus.offline) {
        _connectionRestored = false;
      } else if (wasOffline && status == NetworkStatus.available) {
        _connectionRestored = true;
      }
    });
  }

  @override
  void dispose() {
    _connectivity?.removeListener(_onConnectivityChanged);
    _draftDebounce?.cancel();

    // Preserve the latest changes when leaving the form.
    if (_hasEditedDraft && !_savedRemotely) {
      _saveLocalDraft();
    }
    _nameController.dispose();
    _brandController.dispose();
    _priceController.dispose();
    _imageUrlController.dispose();
    _productUrlController.dispose();

    super.dispose();
  }

  void _refresh() {
    if (!mounted) return;

    setState(() {});
    _scheduleDraftSave();
  }

  void _scheduleDraftSave() {
    if (_restoringDraft || _savedRemotely || _draftUserId == null) {
      return;
    }

    _hasEditedDraft = true;

    _draftDebounce?.cancel();

    _draftDebounce = Timer(const Duration(milliseconds: 500), _saveLocalDraft);
  }

  void _saveLocalDraft() {
    final store = _draftStore;
    final userId = _draftUserId;

    if (store == null || userId == null || _savedRemotely) {
      return;
    }

    final draft = LocalProductDraft(
      userId: userId,
      wishlistId: _selectedWishlistId,
      categoryId: _selectedCategoryId,
      wishlistName: _selectedWishlistName,
      wishlistEmoji: _selectedWishlistEmoji,
      name: _nameController.text,
      brand: _brandController.text,
      priceText: _priceController.text,
      imageUrl: _imageUrlController.text,
      productUrl: _productUrlController.text,
    );

    // Serialize writes so an older autosave cannot overwrite a newer one.
    _pendingDraftWrites = _pendingDraftWrites
        .then((_) => store.save(draft, originWishlistId: _originWishlistId))
        .catchError((Object error, StackTrace stackTrace) {
          debugPrint('Could not save local product draft: $error');
        });
  }

  Future<void> _restoreLocalDraft(String userId) async {
    final store = _draftStore;
    if (store == null) return;

    try {
      final draft = await store.load(
        userId,
        originWishlistId: _originWishlistId,
      );

      // Never replace changes the user made while SQLite was loading.
      if (!mounted || draft == null || _hasEditedDraft || _savedRemotely) {
        return;
      }

      _restoringDraft = true;

      try {
        _nameController.text = draft.name;
        _brandController.text = draft.brand;
        _priceController.text = draft.priceText;
        _imageUrlController.text = draft.imageUrl;
        _productUrlController.text = draft.productUrl;

        // A wishlist selected through navigation takes precedence.
        // A wishlist opened from its Add Item button always wins over
        // previously saved form values. Only central + can restore a choice.
        if (_originWishlistId == null && _selectedWishlistId == null) {
          _selectedWishlistId = draft.wishlistId;
          _selectedCategoryId = draft.categoryId;
          _selectedWishlistName = draft.wishlistName;
          _selectedWishlistEmoji = draft.wishlistEmoji;
        }
      } finally {
        _restoringDraft = false;
      }

      if (mounted) {
        setState(() {});
      }
    } catch (error) {
      debugPrint('Could not restore local product draft: $error');
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
              'emoji': summary.wishlist.emoji,
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
      // Check connectivity again before attempting the remote save.
      await _connectivity?.refresh();
      if (!mounted) return;

      if (_connectivity?.isOffline == true) {
        // Keep the product draft locally.
        _draftDebounce?.cancel();
        _saveLocalDraft();

        if (mounted) {
          _showMessage('You are offline. Your draft is saved locally.');
        }

        return;
      }

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
      // Firebase confirmed the product creation.
      _savedRemotely = true;
      _draftDebounce?.cancel();

      // Let previously scheduled local writes finish before deleting.
      await _pendingDraftWrites;

      try {
        final userId = _draftUserId;
        if (userId != null) {
          await _draftStore?.clear(userId, originWishlistId: _originWishlistId);
        }
      } catch (error) {
        // A local cleanup failure must not turn a successful
        // Firebase save into an apparent product-save failure.
        debugPrint('Could not clear saved product draft: $error');
      }
      if (!mounted) return;

      Navigator.pushReplacementNamed(
        context,
        AppRoutes.wishlistDetail,
        arguments: {
          'wishlistId': _selectedWishlistId,
          'categoryId': _selectedCategoryId,
          'categoryName': _selectedWishlistName,
          'emoji': _selectedWishlistEmoji,
        },
      );
    } on InputPolicyException catch (error) {
      if (mounted) _showMessage(error.message);
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
    return Text(text, style: WhyNotTextStyles.serif(size: 20));
  }

  Widget _textField({
    required TextEditingController controller,
    required String hint,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
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
              Text('New Product', style: WhyNotTextStyles.serif(size: 30)),

              const SizedBox(height: 42),

              _label('Name'),

              const SizedBox(height: 14),

              _textField(controller: _nameController, hint: 'Product name'),

              const SizedBox(height: 30),

              _label('Brand'),

              const SizedBox(height: 14),

              _textField(controller: _brandController, hint: 'Brand name'),

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
                  TextInputFormatter.withFunction((oldValue, newValue) {
                    final isValid = RegExp(
                      r'^\d*(?:[.,]\d*)?$',
                    ).hasMatch(newValue.text);

                    return isValid ? newValue : oldValue;
                  }),
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

              Text('Save to:', style: WhyNotTextStyles.muted(size: 15)),

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
                    border: Border.all(color: WhyNotColors.border),
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
                const Center(child: CircularProgressIndicator())
              else if (_wishlists.isEmpty)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Create a wishlist before adding a product.',
                      style: WhyNotTextStyles.muted(size: 14),
                    ),
                    const SizedBox(height: 12),
                    TextButton.icon(
                      onPressed: () {
                        Navigator.pushReplacementNamed(
                          context,
                          AppRoutes.newWishlist,
                        );
                      },
                      icon: const Icon(Icons.add_circle_outline),
                      label: const Text('Create Wishlist'),
                    ),
                  ],
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
                          _selectedWishlistName = name;
                          _selectedWishlistEmoji = wishlist['emoji'];
                        });
                        _scheduleDraftSave();
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
              // Juliana - Sprint 3: Eventual Connectivity.
              if (_network == NetworkStatus.offline) ...[
                ConnectivityNotice(
                  label: 'Offline',
                  title: "You're offline",
                  message:
                      'Your draft is saved locally. You can continue editing '
                      'and save your product when you reconnect.',
                  icon: Icons.wifi_off_rounded,
                  actionLabel: 'Check connection',
                  onAction: () {
                    final connectivity = _connectivity;
                    if (connectivity != null) {
                      unawaited(connectivity.refresh());
                    }
                  },
                ),
                const SizedBox(height: 16),
              ] else if (_connectionRestored &&
                  _network == NetworkStatus.available) ...[
                const ConnectivityNotice(
                  label: 'Connection',
                  title: 'Connection detected!',
                  message:
                      'You can now try saving your product. '
                      'Your draft is still available.',
                  icon: Icons.wifi_rounded,
                ),
                const SizedBox(height: 16),
              ],
              SizedBox(
                width: double.infinity,
                height: 44,
                child: FilledButton(
                  onPressed:
                      _canSave &&
                          !_isSaving &&
                          _network != NetworkStatus.offline
                      ? _saveItem
                      : null,
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
      bottomNavigationBar: const AppBottomNavigation(selectedIndex: 2),
    );
  }
}

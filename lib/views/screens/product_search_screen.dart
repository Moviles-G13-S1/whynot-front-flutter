import 'package:flutter/material.dart';

import '../../app/app_routes.dart';
import '../../app/dependencies_scope.dart';
import '../../app/whynot_theme.dart';
import '../../controllers/product_search_controller.dart';
import '../../models/category_catalog.dart';
import '../../models/product.dart';

class ProductSearchScreen extends StatefulWidget {
  const ProductSearchScreen({super.key});

  @override
  State<ProductSearchScreen> createState() => _ProductSearchScreenState();
}

class _ProductSearchScreenState extends State<ProductSearchScreen> {
  final _query = TextEditingController();
  final _min = TextEditingController();
  final _max = TextEditingController();
  final _search = const ProductSearchController();
  String _category = '';
  String? _ownerId;
  Stream<OwnerProducts>? _products;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final controller = context.dependencies.productController;
    final ownerId = controller.currentUserId;
    if (_ownerId != ownerId || (_products == null && ownerId != null)) {
      _ownerId = ownerId;
      _products = ownerId == null
          ? null
          : controller.watchCurrentOwnerProducts();
    }
  }

  @override
  void dispose() {
    _query.dispose();
    _min.dispose();
    _max.dispose();
    super.dispose();
  }

  double? _price(TextEditingController controller) =>
      double.tryParse(controller.text.trim());

  bool _validPrice(TextEditingController controller) {
    if (controller.text.trim().isEmpty) return true;
    final value = _price(controller);
    return value != null && value.isFinite && value >= 0;
  }

  InputDecoration _fieldDecoration(String label, {Widget? prefixIcon}) =>
      InputDecoration(
        hintText: label,
        hintStyle: WhyNotTextStyles.muted(size: 14),
        prefixIcon: prefixIcon,
        filled: true,
        fillColor: WhyNotColors.field,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 15,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(24),
          borderSide: const BorderSide(color: WhyNotColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(24),
          borderSide: const BorderSide(color: WhyNotColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(24),
          borderSide: const BorderSide(color: Colors.black87),
        ),
      );

  Widget _priceField(TextEditingController controller, String label) =>
      TextField(
        controller: controller,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: _fieldDecoration(label),
        onChanged: (_) => setState(() {}),
      );

  Widget _filters() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      TextField(
        controller: _query,
        decoration: _fieldDecoration(
          'Search by name or brand',
          prefixIcon: const Icon(Icons.search, color: WhyNotColors.muted),
        ),
        onChanged: (_) => setState(() {}),
      ),
      const SizedBox(height: 22),
      Text('Filters', style: WhyNotTextStyles.serif(size: 22)),
      const SizedBox(height: 12),
      Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: WhyNotColors.form,
          borderRadius: BorderRadius.circular(22),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Category', style: WhyNotTextStyles.muted(size: 13)),
            const SizedBox(height: 7),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 15),
              decoration: BoxDecoration(
                color: WhyNotColors.field,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: WhyNotColors.border),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  isExpanded: true,
                  value: _category,
                  dropdownColor: WhyNotColors.field,
                  icon: const Icon(
                    Icons.keyboard_arrow_down,
                    color: WhyNotColors.muted,
                  ),
                  items: [
                    const DropdownMenuItem(
                      value: '',
                      child: Text('All categories'),
                    ),
                    for (final category in CategoryCatalog.labelsById.entries)
                      DropdownMenuItem(
                        value: category.key,
                        child: Text(category.value),
                      ),
                  ],
                  onChanged: (value) => setState(() => _category = value ?? ''),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Text('Price range', style: WhyNotTextStyles.muted(size: 13)),
            const SizedBox(height: 7),
            Row(
              children: [
                Expanded(child: _priceField(_min, 'Min price')),
                const SizedBox(width: 10),
                Expanded(child: _priceField(_max, 'Max price')),
              ],
            ),
          ],
        ),
      ),
      Align(
        alignment: Alignment.centerRight,
        child: TextButton(
          style: linkButtonStyle(),
          onPressed: () => setState(() {
            _query.clear();
            _min.clear();
            _max.clear();
            _category = '';
          }),
          child: const Text('Clear filters'),
        ),
      ),
    ],
  );

  Widget _placeholder() => const ColoredBox(
    color: WhyNotColors.card,
    child: Center(
      child: Icon(Icons.shopping_bag_outlined, color: WhyNotColors.muted),
    ),
  );

  Widget _productCard(Product product) {
    final category =
        CategoryCatalog.labelsById[product.categoryId] ?? product.categoryId;
    final url = Uri.tryParse(product.imageUrl.trim());
    final hasImage =
        url != null &&
        (url.scheme == 'https' || url.scheme == 'http') &&
        url.host.isNotEmpty;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: WhyNotColors.field,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: WhyNotColors.divider),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => Navigator.pushNamed(
            context,
            AppRoutes.productDetail,
            arguments: {'productId': product.id, 'sourceTab': 1},
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: SizedBox(
                    width: 76,
                    height: 86,
                    child: hasImage
                        ? Image.network(
                            product.imageUrl.trim(),
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) =>
                                _placeholder(),
                          )
                        : _placeholder(),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        product.name,
                        style: WhyNotTextStyles.serif(size: 20),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 5),
                      Text(
                        '${product.brand} · $category',
                        style: WhyNotTextStyles.muted(size: 13),
                      ),
                      const SizedBox(height: 7),
                      Text(
                        '\$${product.price.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      if (product.purchased)
                        Padding(
                          padding: const EdgeInsets.only(top: 5),
                          child: Text(
                            'Purchased',
                            style: WhyNotTextStyles.muted(size: 12),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                const Icon(Icons.chevron_right, color: WhyNotColors.muted),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _message(String text) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 30),
    child: Center(
      child: Text(
        text,
        style: WhyNotTextStyles.muted(size: 14),
        textAlign: TextAlign.center,
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final min = _price(_min);
    final max = _price(_max);
    final invalid =
        !_validPrice(_min) ||
        !_validPrice(_max) ||
        (min != null && max != null && min > max);
    return Scaffold(
      backgroundColor: WhyNotColors.background,
      appBar: AppBar(
        backgroundColor: WhyNotColors.background,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        title: const Text(
          'WHYNOT',
          style: TextStyle(
            letterSpacing: 4,
            fontSize: 15,
            color: WhyNotColors.muted,
          ),
        ),
      ),
      body: SafeArea(
        top: false,
        child: StreamBuilder<OwnerProducts>(
          key: ValueKey(_ownerId),
          stream: _products,
          builder: (context, snapshot) {
            final data = snapshot.data;
            final canFilter =
                !invalid &&
                _ownerId != null &&
                !snapshot.hasError &&
                data != null;
            final fromCache = data?.fromCache ?? false;
            final results =
                invalid || _ownerId == null || snapshot.hasError || data == null
                ? const <Product>[]
                : _search.filter(
                    data.products,
                    query: _query.text,
                    categoryId: _category.isEmpty ? null : _category,
                    minPrice: min,
                    maxPrice: max,
                  );
            return CustomScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(25, 22, 25, 8),
                  sliver: SliverToBoxAdapter(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Search products',
                          style: WhyNotTextStyles.serif(size: 30),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Find saved items across all your wishlists.',
                          style: WhyNotTextStyles.muted(size: 15),
                        ),
                        const SizedBox(height: 24),
                        _filters(),
                        const SizedBox(height: 8),
                        if (canFilter) ...[
                          if (fromCache)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: Text(
                                'Showing cached data; results may be incomplete.',
                                style: WhyNotTextStyles.muted(size: 13),
                              ),
                            ),
                          Text(
                            'Results',
                            style: WhyNotTextStyles.serif(size: 23),
                          ),
                          const SizedBox(height: 7),
                          Text(
                            '${results.length} products found',
                            style: WhyNotTextStyles.muted(size: 14),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                if (!canFilter || results.isEmpty)
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 25),
                    sliver: SliverToBoxAdapter(
                      child: invalid
                          ? _message('Enter a valid price range.')
                          : _ownerId == null
                          ? _message('Please log in.')
                          : snapshot.hasError
                          ? _message('Could not load products.')
                          : data == null
                          ? const Padding(
                              padding: EdgeInsets.all(30),
                              child: Center(child: CircularProgressIndicator()),
                            )
                          : _message('No matching products.'),
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(25, 8, 25, 24),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) => _productCard(results[index]),
                        childCount: results.length,
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

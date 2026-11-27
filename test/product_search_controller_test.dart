import 'package:flutter_test/flutter_test.dart';
import 'package:whynot_mobile/controllers/product_search_controller.dart';
import 'package:whynot_mobile/models/product.dart';

Product item(
  String id,
  String name,
  String brand,
  String category,
  double price,
) => Product(
  id: id,
  ownerId: 'user',
  wishlistId: 'wishlist',
  categoryId: category,
  name: name,
  brand: brand,
  price: price,
  imageUrl: '',
  productUrl: '',
  purchased: false,
);

void main() {
  const controller = ProductSearchController();
  final products = [
    item('2', 'AirPods Pro', 'Apple', 'technology', 249),
    item('1', 'AirPods Max', 'Apple', 'technology', 549),
    item('3', 'Lip Oil', 'Dior', 'beauty', 40),
  ];

  test('async search matches synchronous results with filters', () async {
    final request = (
      products: products,
      query: ' APPLE ',
      categoryId: 'technology',
      minPrice: 100.0,
      maxPrice: 300.0,
    );
    final results = await controller.filterAsync(request);
    expect(results.map((p) => p.id), ['2']);
    expect(
      results.map((p) => p.id),
      controller
          .filter(
            products,
            query: request.query,
            categoryId: request.categoryId,
            minPrice: request.minPrice,
            maxPrice: request.maxPrice,
          )
          .map((p) => p.id),
    );
  });

  test('async search sorts results and leaves input unchanged', () async {
    final results = await controller.filterAsync((
      products: products,
      query: '',
      categoryId: null,
      minPrice: null,
      maxPrice: null,
    ));
    expect(results.map((p) => p.id), ['1', '2', '3']);
    expect(products.map((p) => p.id), ['2', '1', '3']);
  });

  test('async search handles no matches', () async {
    final results = await controller.filterAsync((
      products: products,
      query: 'missing',
      categoryId: null,
      minPrice: null,
      maxPrice: null,
    ));
    expect(results, isEmpty);
  });
}

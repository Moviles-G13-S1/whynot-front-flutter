import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whynot_mobile/controllers/auth_controller.dart';
import 'package:whynot_mobile/controllers/product_controller.dart';
import 'package:whynot_mobile/controllers/profile_controller.dart';
import 'package:whynot_mobile/controllers/wishlist_controller.dart';
import 'package:whynot_mobile/app/dependencies_scope.dart';
import 'package:whynot_mobile/models/auth_user.dart';
import 'package:whynot_mobile/models/input_policy.dart';
import 'package:whynot_mobile/models/product.dart';
import 'package:whynot_mobile/models/profile_photo.dart';
import 'package:whynot_mobile/models/repositories/profile_photo_repository.dart';
import 'package:whynot_mobile/models/user_profile.dart';
import 'package:whynot_mobile/models/wishlist.dart';
import 'package:whynot_mobile/views/widgets/wishlist_card.dart';
import 'package:whynot_mobile/views/widgets/city_selector.dart';
import 'package:whynot_mobile/views/screens/create_account_screen.dart';

import 'fakes/app_dependencies_fixture.dart';
import 'fakes/in_memory_repositories.dart';

class _UnusedPhotos implements ProfilePhotoRepository {
  @override
  Future<ProfilePhoto?> pick() async => null;
  @override
  Future<String> upload(String userId, ProfilePhoto photo) async => '';
  @override
  Future<String> getDownloadUrl(String path) async => '';
  @override
  Future<void> delete(String path) async {}
}

void main() {
  test(
    'emoji forms are rejected while accented and non-emoji text remains valid',
    () {
      for (final value in ['🎁', '👩🏽‍💻', '🇨🇴', '❤️', '1️⃣', '™️']) {
        expect(InputPolicy.containsEmoji(value), isTrue, reason: value);
      }
      for (final value in ['José María', 'Bogotá', '東京', 'crème brûlée', '™']) {
        expect(InputPolicy.containsEmoji(value), isFalse, reason: value);
      }
    },
  );

  test(
    'authentication fields reject emoji before reaching the repository',
    () async {
      final auth = InMemoryAuthRepository();
      final controller = AuthController(
        authRepository: auth,
        userRepository: InMemoryUserRepository(),
      );
      for (final fields in [
        (
          name: 'Ada 👩🏽‍💻',
          email: 'ada@example.com',
          password: 'password123',
        ),
        (name: 'Ada', email: 'ada🎁@example.com', password: 'password123'),
        (name: 'Ada', email: 'ada@example.com', password: 'password🎁'),
      ]) {
        await expectLater(
          controller.createAccount(
            name: fields.name,
            email: fields.email,
            password: fields.password,
            gender: 'Female',
            age: 28,
            preferredCategoryId: 'fashion',
            cityId: 'bogota',
          ),
          throwsA(isA<InputPolicyException>()),
        );
        expect(auth.currentUser, isNull);
      }
      await controller.createAccount(
        name: 'José María',
        email: 'jose@example.com',
        password: 'password123',
        gender: 'Male',
        age: 28,
        preferredCategoryId: 'fashion',
        cityId: 'bogota',
      );
      expect(
        () => controller.signIn(
          email: 'legacy@example.com',
          password: 'legacy🎁',
        ),
        throwsA(isA<InputPolicyException>()),
      );
      await controller.changePassword(
        currentPassword: 'currentpassword123',
        newPassword: 'newpassword123',
      );
      expect(
        () => controller.changePassword(
          currentPassword: 'currentpassword123',
          newPassword: 'new🎁password',
        ),
        throwsA(isA<InputPolicyException>()),
      );
      expect(
        () => controller.changePassword(
          currentPassword: 'current🎁password',
          newPassword: 'newpassword123',
        ),
        throwsA(isA<InputPolicyException>()),
      );
    },
  );

  test(
    'profile edits reject emoji and accept corrected legacy names',
    () async {
      final users = InMemoryUserRepository()
        ..profiles['owner'] = const UserProfile(
          id: 'owner',
          name: 'Old 🎁',
          email: 'owner@example.com',
          gender: 'Female',
          age: 30,
          preferredCategoryId: 'fashion',
          cityId: 'bogota',
        );
      final controller = ProfileController(
        authRepository: InMemoryAuthRepository(
          user: const AuthUser(id: 'owner', email: 'owner@example.com'),
        ),
        userRepository: users,
        photoRepository: _UnusedPhotos(),
      );
      const invalid = UserProfileUpdate(
        name: 'Old 🎁',
        gender: 'Female',
        age: 30,
        preferredCategoryId: 'fashion',
        cityId: 'bogota',
      );
      expect(
        () => controller.updateCurrentProfile(invalid),
        throwsA(isA<InputPolicyException>()),
      );
      await controller.updateCurrentProfile(
        const UserProfileUpdate(
          name: 'María',
          gender: 'Female',
          age: 30,
          preferredCategoryId: 'fashion',
          cityId: 'bogota',
        ),
      );
      expect(users.profiles['owner']!.name, 'María');
    },
  );

  test('create and edit products share emoji and URL checks', () async {
    final auth = InMemoryAuthRepository(
      user: const AuthUser(id: 'owner', email: 'owner@example.com'),
    );
    final products = InMemoryProductRepository();
    final controller = ProductController(
      authRepository: auth,
      productRepository: products,
      wishlistController: WishlistController(
        authRepository: auth,
        wishlistRepository: InMemoryWishlistRepository(),
      ),
    );
    ProductDraft draft({
      String name = 'Cámara',
      String brand = 'Muñoz',
      String imageUrl = 'https://example.com/cámara.jpg',
      String productUrl = '',
    }) => ProductDraft(
      wishlistId: 'wishlist-1',
      categoryId: 'fashion',
      name: name,
      brand: brand,
      price: 12,
      imageUrl: imageUrl,
      productUrl: productUrl,
    );
    await controller.create(draft());
    expect(
      (await controller.watchCurrentProducts().first).single.name,
      'Cámara',
    );
    for (final invalid in [
      draft(name: 'Cámara 🎁'),
      draft(brand: 'Muñoz 🇨🇴'),
      draft(imageUrl: '🎁'),
      draft(productUrl: 'https://example.com/🎁'),
      draft(imageUrl: 'not-a-url'),
    ]) {
      await expectLater(
        controller.create(invalid),
        throwsA(isA<InputPolicyException>()),
      );
      expect(
        () => controller.update('product-1', invalid),
        throwsA(isA<InputPolicyException>()),
      );
    }
    await controller.update(
      'product-1',
      draft(productUrl: 'https://example.com/a?x=1'),
    );
    expect(InputPolicy.isOptionalWebUrl(''), isTrue);
    expect(
      InputPolicy.isOptionalWebUrl('https://example.com/%F0%9F%8E%81'),
      isTrue,
    );
  });

  testWidgets('curated wishlist emoji persists and takes thumbnail priority', (
    tester,
  ) async {
    final auth = InMemoryAuthRepository(
      user: const AuthUser(id: 'owner', email: 'owner@example.com'),
    );
    final repo = InMemoryWishlistRepository();
    final controller = WishlistController(
      authRepository: auth,
      wishlistRepository: repo,
    );
    await controller.create(
      categoryId: 'fashion',
      imageUrl: 'https://example.com/photo.jpg',
      emoji: '🎁',
    );
    final wishlist = (await repo.getByOwner('owner')).single;
    expect(wishlist.emoji, '🎁');
    expect(
      () => controller.create(categoryId: 'fashion', imageUrl: '', emoji: '💥'),
      throwsA(isA<InputPolicyException>()),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 131,
              height: 230,
              child: WishlistCard(
                label: 'Fashion',
                imageUrl: wishlist.imageUrl,
                emoji: wishlist.emoji,
                onTap: () {},
              ),
            ),
          ),
        ),
      ),
    );
    expect(find.text('🎁'), findsOneWidget);
    expect(find.byType(Image), findsNothing);
  });

  testWidgets('legacy wishlist without emoji stays renderable', (tester) async {
    const legacy = Wishlist(
      id: 'old',
      ownerId: 'owner',
      categoryId: 'fashion',
      imageUrl: '',
    );
    expect(legacy.emoji, isNull);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 131,
              height: 230,
              child: WishlistCard(
                label: 'Fashion',
                imageUrl: legacy.imageUrl,
                emoji: legacy.emoji,
                onTap: () {},
              ),
            ),
          ),
        ),
      ),
    );
    expect(find.text('Fashion'), findsOneWidget);
    expect(find.byType(Image), findsNothing);
  });

  testWidgets('registration reports emoji pasted into city search', (
    tester,
  ) async {
    await tester.pumpWidget(
      DependenciesScope(
        dependencies: createTestDependencies(),
        child: const MaterialApp(home: CreateAccountScreen()),
      ),
    );
    await tester.pumpAndSettle();
    final selector = tester.widget<CitySelector>(find.byType(CitySelector));
    selector.controller.text = 'Bogotá🎁';
    await tester.ensureVisible(find.text('Create an account').last);
    await tester.tap(find.text('Create an account').last);
    await tester.pump();
    expect(
      find.text('You cannot include emojis in your city.'),
      findsOneWidget,
    );
  });
}

import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whynot_mobile/controllers/home_controller.dart';
import 'package:whynot_mobile/controllers/live_section.dart';
import 'package:whynot_mobile/controllers/profile_load_controller.dart';
import 'package:whynot_mobile/models/city.dart';
import 'package:whynot_mobile/models/user_profile.dart';
import 'package:whynot_mobile/models/wishlist.dart';

const profile = UserProfile(
  id: 'alice',
  name: 'Alice',
  email: 'alice@example.com',
  gender: 'Female',
  age: 22,
  preferredCategoryId: 'fashion',
);

Future<void> flush() => Future<void>.delayed(Duration.zero);

void main() {
  test(
    'Home starts both sources before either responds and keeps live updates',
    () async {
      final profiles = StreamController<UserProfile?>();
      final wishlists = StreamController<List<WishlistSummary>>();
      var profileStarts = 0;
      var wishlistStarts = 0;
      final controller = HomeController(
        watchProfile: () {
          profileStarts++;
          return profiles.stream;
        },
        watchWishlists: () {
          wishlistStarts++;
          return wishlists.stream;
        },
      );
      await flush();
      expect(profileStarts, 1);
      expect(wishlistStarts, 1);
      expect(
        controller.profile.snapshot.connectionState,
        ConnectionState.waiting,
      );
      expect(
        controller.wishlists.snapshot.connectionState,
        ConnectionState.waiting,
      );
      wishlists.add([]);
      await flush();
      expect(controller.wishlists.snapshot.hasData, isTrue);
      expect(
        controller.profile.snapshot.connectionState,
        ConnectionState.waiting,
      );
      profiles.add(profile);
      await flush();
      expect(controller.profile.snapshot.data, profile);
      profiles.add(null);
      await flush();
      expect(controller.profile.snapshot.data, isNull);
      expect(profileStarts, 1);
      expect(wishlistStarts, 1);
      controller.dispose();
      expect(profiles.hasListener, isFalse);
      expect(wishlists.hasListener, isFalse);
      await profiles.close();
      await wishlists.close();
    },
  );

  test(
    'Home isolates failures and retries only the failed subscription',
    () async {
      final profiles = StreamController<UserProfile?>.broadcast();
      final wishlists = StreamController<List<WishlistSummary>>.broadcast();
      var profileStarts = 0;
      var wishlistStarts = 0;
      final controller = HomeController(
        watchProfile: () {
          profileStarts++;
          return profiles.stream;
        },
        watchWishlists: () {
          wishlistStarts++;
          return wishlists.stream;
        },
      );
      await flush();
      wishlists.add([]);
      profiles.addError(StateError('unavailable'));
      await flush();
      expect(controller.profile.snapshot.hasError, isTrue);
      expect(controller.wishlists.snapshot.data, isEmpty);
      controller.profile.start();
      await flush();
      expect(profileStarts, 2);
      expect(wishlistStarts, 1);
      profiles.add(profile);
      await flush();
      expect(controller.profile.snapshot.data, profile);
      expect(controller.profile.snapshot.hasError, isFalse);
      controller.dispose();
      await profiles.close();
      await wishlists.close();
    },
  );

  test(
    'Profile starts cities before profile arrives and renders profile without cities',
    () async {
      final profiles = StreamController<UserProfile?>();
      final cities = Completer<List<City>>();
      var cityStarts = 0;
      final controller = ProfileLoadController(
        watchProfile: () => profiles.stream,
        getCities: () {
          cityStarts++;
          return cities.future;
        },
      );
      await flush();
      expect(profiles.hasListener, isTrue);
      expect(cityStarts, 1);
      profiles.add(profile);
      await flush();
      expect(controller.profile.snapshot.data, profile);
      expect(
        controller.cities.snapshot.connectionState,
        ConnectionState.waiting,
      );
      cities.completeError(StateError('catalog unavailable'));
      await flush();
      expect(controller.cities.snapshot.hasError, isTrue);
      expect(controller.profile.snapshot.data, profile);
      controller.dispose();
      await profiles.close();
    },
  );

  test(
    'Retry ignores an obsolete Future and disposal ignores pending completions',
    () async {
      final first = Completer<int>();
      final second = Completer<int>();
      final third = Completer<int>();
      final requests = [first, second, third];
      var calls = 0;
      final section = LiveSection(
        () => Stream.fromFuture(requests[calls++].future),
      );
      section.start();
      await flush();
      section.start();
      // Canceled Future streams can finish later; their results must be ignored.
      first.complete(1);
      await flush();
      second.complete(2);
      await flush();
      expect(section.snapshot.data, 2);
      var notifications = 0;
      section.addListener(() => notifications++);
      section.start();
      await flush();
      section.dispose();
      final beforeCompletion = notifications;
      third.completeError(StateError('late error'));
      await flush();
      expect(notifications, beforeCompletion);
    },
  );
}

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:whynot_mobile/app/application_error_handlers.dart';
import 'package:whynot_mobile/controllers/application_error_reporter.dart';
import 'package:whynot_mobile/controllers/connectivity_status.dart';
import 'package:whynot_mobile/controllers/home_controller.dart';
import 'package:whynot_mobile/infrastructure/repositories/sqlite_application_error_queue.dart';
import 'package:whynot_mobile/models/application_error_event.dart';
import 'package:whynot_mobile/models/input_policy.dart';
import 'package:whynot_mobile/models/network_failure.dart';
import 'package:whynot_mobile/models/repositories/application_error_repository.dart';
import 'package:whynot_mobile/models/repositories/auth_repository.dart';
import 'package:whynot_mobile/models/user_profile.dart';

class MemoryErrorQueue implements ApplicationErrorQueue {
  final rows = <String, ApplicationErrorEvent>{};
  bool fail = false;
  @override
  Future<void> add(ApplicationErrorEvent event) async {
    if (fail) throw StateError('local storage unavailable');
    rows.putIfAbsent(event.id, () => event);
  }

  @override
  Future<List<ApplicationErrorEvent>> pending(String userId) async => rows
      .values
      .where((event) => event.ownerId == null || event.ownerId == userId)
      .take(25)
      .toList();
  @override
  Future<bool> claim(String eventId, String userId) async {
    final event = rows[eventId];
    if (event == null || (event.ownerId != null && event.ownerId != userId)) {
      return false;
    }
    rows[eventId] = ApplicationErrorEvent.fromLocalMap({
      ...event.toLocalMap(),
      'ownerId': userId,
    });
    return true;
  }

  @override
  Future<void> remove(String eventId) async => rows.remove(eventId);
}

class ErrorSink implements ApplicationErrorSink {
  final accepted = <String, ApplicationErrorEvent>{};
  final owners = <String>[];
  int attempts = 0;
  bool fail = false;
  bool loseAck = false;
  @override
  Future<void> send(ApplicationErrorEvent event, String userId) async {
    attempts++;
    if (fail) throw StateError('backend unavailable');
    accepted.putIfAbsent(event.id, () => event);
    owners.add(userId);
    if (loseAck) throw TimeoutException('acknowledgement lost');
  }
}

ApplicationErrorEvent event(int i, {String? owner}) => ApplicationErrorEvent(
  id: i.toRadixString(16).padLeft(32, '0'),
  occurredAt: DateTime.utc(2026, 10, 28).add(Duration(seconds: i)),
  platform: 'ios',
  feature: 'profile',
  operation: 'load_profile',
  code: 'network',
  source: 'operation',
  ownerId: owner,
);
Future<void> tick() => Future<void>.delayed(Duration.zero);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(sqfliteFfiInit);
  late MemoryErrorQueue queue;
  late ErrorSink sink;
  late ConnectivityStatus net;
  late ApplicationErrorReporter reporter;
  String? user;
  setUp(() {
    user = null;
    queue = MemoryErrorQueue();
    sink = ErrorSink();
    net = ConnectivityStatus(observe: false);
    reporter = ApplicationErrorReporter(
      queue: queue,
      sink: sink,
      currentUserId: () => user,
      connectivity: net,
      platform: 'ios',
      clock: () => DateTime.utc(2026, 10, 28, 15),
    );
  });
  tearDown(() {
    reporter.dispose();
    net.dispose();
  });

  test(
    'excludes normal validation and known offline policy rejections',
    () async {
      for (final error in [
        const InputPolicyException('private form input'),
        const NetworkFailure(),
        const AuthFailure('network-request-failed', NetworkFailure()),
        const AuthFailure('invalid-credential'),
        const AuthFailure('weak-password'),
      ]) {
        await reporter.capture(error, feature: 'auth', operation: 'sign_in');
      }
      expect(queue.rows, isEmpty);
      // Malformed backend data is a technical failure, not form validation.
      expect(
        ApplicationErrorReporter.classify(const FormatException('bad data')),
        'unexpected',
      );
      expect(
        ApplicationErrorReporter.classify(
          FirebaseException(plugin: 'auth', code: 'network-request-failed'),
        ),
        'network',
      );
    },
  );

  test(
    'serializes only safe categories, never messages, stacks or form contents',
    () async {
      await reporter.capture(
        FirebaseException(
          plugin: 'firestore',
          code: 'permission-denied',
          message: 'alice@example.com password=secret',
        ),
        feature: 'profile',
        operation: 'update_profile',
      );
      final record = queue.rows.values.single;
      expect(record.code, 'permission');
      expect(record.occurredAt, DateTime.utc(2026, 10, 28, 15));
      final encoded = jsonEncode(record.toLocalMap());
      expect(encoded, isNot(contains('alice@example.com')));
      expect(encoded, isNot(contains('secret')));
      expect(encoded, isNot(contains('message')));
      expect(RegExp(r'^[0-9a-f]{32}$').hasMatch(record.id), isTrue);
    },
  );

  test(
    'pre-login errors persist until a successful authenticated flush',
    () async {
      await reporter.capture(
        StateError('unexpected'),
        feature: 'auth',
        operation: 'register',
      );
      expect(sink.attempts, 0);
      user = 'alice';
      await reporter.flush();
      expect(sink.accepted.length, 1);
      expect(sink.owners, ['alice']);
      expect(queue.rows, isEmpty);
    },
  );

  test(
    'offline events drain on reconnection with their original occurrence time',
    () async {
      user = 'alice';
      net.setStatus(NetworkStatus.offline);
      await reporter.capture(
        TimeoutException('private details'),
        feature: 'home',
        operation: 'load_profile',
      );
      final id = queue.rows.keys.single;
      expect(sink.attempts, 0);
      net.setStatus(NetworkStatus.available);
      await reporter.flush();
      expect(sink.accepted[id]!.occurredAt, DateTime.utc(2026, 10, 28, 15));
      expect(queue.rows, isEmpty);
    },
  );

  test(
    'lost ACK retries the same ID and does not duplicate the server event',
    () async {
      user = 'alice';
      sink.loseAck = true;
      await reporter.capture(
        StateError('technical failure'),
        feature: 'profile',
        operation: 'save_photo',
      );
      expect(queue.rows.length, 1);
      expect(sink.accepted.length, 1);
      sink.loseAck = false;
      await reporter.flush();
      expect(sink.attempts, 2);
      expect(sink.accepted.length, 1);
      expect(queue.rows, isEmpty);
    },
  );

  test(
    'another signed-in owner cannot flush a previous owners backlog',
    () async {
      user = 'alice';
      net.setStatus(NetworkStatus.offline);
      await reporter.capture(
        StateError('technical'),
        feature: 'profile',
        operation: 'load_profile',
      );
      user = 'bob';
      net.setStatus(NetworkStatus.available);
      await reporter.flush();
      expect(sink.accepted, isEmpty);
      expect(queue.rows.length, 1);
      user = 'alice';
      await reporter.flush();
      expect(sink.owners, ['alice']);
    },
  );

  test(
    'one failure crossing an operation and framework is counted once',
    () async {
      final failure = StateError('private');
      await reporter.capture(
        failure,
        feature: 'profile',
        operation: 'load_profile',
      );
      await reporter.capture(
        failure,
        feature: 'runtime',
        operation: 'unhandled',
        source: 'framework',
      );
      expect(queue.rows.length, 1);
      await reporter.capture(
        failure,
        feature: 'profile',
        operation: 'load_profile',
      );
      expect(
        queue.rows.length,
        2,
      ); // A separate retry is a separate failing attempt.
    },
  );

  test('telemetry failure never replaces the application error', () async {
    queue.fail = true;
    final failure = StateError('original');
    await expectLater(
      reporter.run<void>(
        feature: 'profile',
        operation: 'load_profile',
        action: () async => throw failure,
      ),
      throwsA(same(failure)),
    );
    await tick();
    expect(queue.rows, isEmpty);
    expect(
      await reporter.run(
        feature: 'auth',
        operation: 'sign_in',
        action: () async => 7,
      ),
      7,
    );
  });

  test(
    'live read failures generate a sanitized event without breaking state',
    () async {
      final profiles = StreamController<UserProfile?>();
      final home = HomeController(
        errorReporter: reporter,
        watchProfile: () => profiles.stream,
        watchWishlists: () => Stream.value([]),
      );
      await tick();
      profiles.addError(TimeoutException('private'));
      await tick();
      expect(home.profile.snapshot.hasError, isTrue);
      expect(queue.rows.values.single.feature, 'home');
      expect(queue.rows.values.single.code, 'timeout');
      home.dispose();
      await profiles.close();
    },
  );

  test(
    'global handlers preserve previous error handling and propagation',
    () async {
      final oldFlutter = FlutterError.onError;
      final oldPlatform = PlatformDispatcher.instance.onError;
      var presented = 0;
      FlutterError.onError = (_) {
        presented++;
      };
      PlatformDispatcher.instance.onError = (_, _) => false;
      final restore = installApplicationErrorHandlers(reporter);
      try {
        FlutterError.onError!(
          FlutterErrorDetails(exception: StateError('framework')),
        );
        expect(
          PlatformDispatcher.instance.onError!(
            StateError('async'),
            StackTrace.current,
          ),
          isFalse,
        );
        await tick();
        expect(presented, 1);
        expect(queue.rows.values.map((e) => e.source).toSet(), {
          'framework',
          'platform',
        });
      } finally {
        restore();
        FlutterError.onError = oldFlutter;
        PlatformDispatcher.instance.onError = oldPlatform;
      }
    },
  );

  test(
    'SQLite queue survives restart, claims ownership, and ignores duplicate inserts',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'whynot-error-queue-',
      );
      final path = '${directory.path}/errors.db';
      var store = SqliteApplicationErrorQueue(
        factory: databaseFactoryFfi,
        databasePath: path,
      );
      try {
        await store.add(event(1));
        await store.add(event(1));
        await store.add(event(2, owner: 'bob'));
        await store.close();
        store = SqliteApplicationErrorQueue(
          factory: databaseFactoryFfi,
          databasePath: path,
        );
        expect((await store.pending('alice')).length, 1);
        expect(await store.claim(event(1).id, 'alice'), isTrue);
        expect(await store.claim(event(1).id, 'bob'), isFalse);
        expect((await store.pending('bob')).length, 1);
        await store.remove(event(1).id);
        expect(await store.pending('alice'), isEmpty);
      } finally {
        await store.close();
        await File(path).delete();
        await directory.delete();
      }
    },
  );

  test('bounded SQLite queue keeps the newest 500 events', () async {
    final store = SqliteApplicationErrorQueue(
      factory: databaseFactoryFfi,
      databasePath: inMemoryDatabasePath,
    );
    try {
      for (var i = 0; i <= 500; i++) {
        await store.add(event(i, owner: 'alice'));
      }
      var count = 0;
      final ids = <String>[];
      while (true) {
        final batch = await store.pending('alice');
        if (batch.isEmpty) break;
        count += batch.length;
        for (final record in batch) {
          ids.add(record.id);
          await store.remove(record.id);
        }
      }
      expect(count, 500);
      expect(ids, isNot(contains(event(0).id)));
      expect(ids, contains(event(500).id));
    } finally {
      await store.close();
    }
  });
}

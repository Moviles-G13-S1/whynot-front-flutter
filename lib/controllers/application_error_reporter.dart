import 'dart:async';
import 'dart:collection';
import 'dart:math';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import '../models/application_error_event.dart';
import '../models/input_policy.dart';
import '../models/network_failure.dart';
import '../models/repositories/application_error_repository.dart';
import '../models/repositories/auth_repository.dart';
import 'connectivity_status.dart';

/// Non-blocking, sanitized telemetry. Its own failures are never reported.
class ApplicationErrorReporter {
  ApplicationErrorReporter({
    required this.queue,
    required this.sink,
    required this.currentUserId,
    required this.connectivity,
    DateTime Function()? clock,
    String? platform,
  }) : _clock = clock ?? DateTime.now,
       _platform =
           platform ??
           (kIsWeb
               ? 'web'
               : defaultTargetPlatform == TargetPlatform.iOS
               ? 'ios'
               : 'android') {
    connectivity.addListener(_connectionChanged);
  }

  final ApplicationErrorQueue queue;
  final ApplicationErrorSink sink;
  final String? Function() currentUserId;
  final ConnectivityStatus connectivity;
  final DateTime Function() _clock;
  final String _platform;
  final _recent = HashMap<Object, ({DateTime at, String source})>.identity();
  Future<void>? _flushing;
  bool _again = false;
  bool _disposed = false;

  static String? classify(Object error, {String source = 'operation'}) {
    if (source == 'operation') {
      if (error is NetworkFailure || error is InputPolicyException) {
        return null;
      }
      if (error is ArgumentError && ['name', 'age'].contains(error.name)) {
        return null;
      }
    }
    String? code;
    if (error is AuthFailure) {
      if (error.cause is NetworkFailure) return null;
      code = error.code;
      if (const {
        'invalid-email',
        'invalid-name',
        'invalid-age',
        'weak-password',
        'email-already-in-use',
        'wrong-password',
        'user-not-found',
        'invalid-credential',
        'requires-recent-login',
      }.contains(code)) {
        return null;
      }
    } else if (error is FirebaseException) {
      code = error.code;
    }
    if (error is TimeoutException) return 'timeout';
    return switch (code) {
      'network-request-failed' || 'unavailable' || 'network-error' => 'network',
      'permission-denied' || 'unauthorized' => 'permission',
      'unauthenticated' || 'no-current-user' => 'unauthenticated',
      'not-found' || 'object-not-found' => 'not_found',
      'too-many-requests' || 'resource-exhausted' => 'rate_limited',
      'deadline-exceeded' || 'retry-limit-exceeded' => 'timeout',
      _ => 'unexpected',
    };
  }

  Future<T> run<T>({
    required String feature,
    required String operation,
    required Future<T> Function() action,
  }) async {
    try {
      return await action();
    } catch (error) {
      report(error, feature: feature, operation: operation);
      rethrow;
    }
  }

  void report(
    Object error, {
    required String feature,
    required String operation,
    String source = 'operation',
  }) {
    unawaited(
      capture(error, feature: feature, operation: operation, source: source),
    );
  }

  Future<void> capture(
    Object error, {
    required String feature,
    required String operation,
    String source = 'operation',
  }) async {
    try {
      if (_disposed ||
          !const {'auth', 'home', 'profile', 'runtime'}.contains(feature) ||
          !const {'operation', 'framework', 'platform'}.contains(source) ||
          !RegExp(r'^[a-z_]{1,48}$').hasMatch(operation)) {
        return;
      }
      final code = classify(error, source: source);
      if (code == null) return;
      final now = _clock().toUtc();
      final previous = _recent[error];
      // One propagated failure can appear in both an operation and a global
      // handler. Distinct attempts from the same source remain distinct events.
      if (previous != null &&
          previous.source != source &&
          now.difference(previous.at).abs() < const Duration(seconds: 1)) {
        return;
      }
      _recent[error] = (at: now, source: source);
      if (_recent.length > 64) _recent.remove(_recent.keys.first);
      final random = Random.secure();
      final id = List.generate(
        16,
        (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
      ).join();
      await queue.add(
        ApplicationErrorEvent(
          id: id,
          occurredAt: now,
          platform: _platform,
          feature: feature,
          operation: operation,
          code: code,
          source: source,
          ownerId: currentUserId(),
        ),
      );
      await flush();
    } catch (_) {
      /* Analytics must never interrupt the original interaction. */
    }
  }

  void _connectionChanged() {
    if (!connectivity.isOffline) unawaited(flush());
  }

  Future<void> flush() {
    if (_disposed || connectivity.isOffline || currentUserId() == null) {
      return Future.value();
    }
    if (_flushing != null) {
      _again = true;
      return _flushing!;
    }
    final result = _drain();
    _flushing = result;
    return result;
  }

  Future<void> _drain() async {
    try {
      do {
        _again = false;
        while (!_disposed && !connectivity.isOffline) {
          final user = currentUserId();
          if (user == null) return;
          final events = await queue.pending(user);
          if (events.isEmpty) break;
          for (final event in events) {
            if (_disposed ||
                currentUserId() != user ||
                connectivity.isOffline) {
              return;
            }
            if (!await queue.claim(event.id, user)) continue;
            if (currentUserId() != user) return;
            await sink.send(event, user);
            await queue.remove(event.id);
          }
        }
      } while (_again && !_disposed && !connectivity.isOffline);
    } catch (_) {
      /* Keep the same IDs for a later retry, including lost ACKs. */
    } finally {
      _flushing = null;
    }
  }

  void dispose() {
    _disposed = true;
    connectivity.removeListener(_connectionChanged);
    _recent.clear();
  }
}

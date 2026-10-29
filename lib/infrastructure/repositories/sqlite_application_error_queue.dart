import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';

import '../../models/application_error_event.dart';
import '../../models/repositories/application_error_repository.dart';

/// Durable bounded outbox. Owner is bound before first send, including events
/// captured before login. Another account cannot transmit an owner's backlog.
class SqliteApplicationErrorQueue implements ApplicationErrorQueue {
  SqliteApplicationErrorQueue({DatabaseFactory? factory, this.databasePath})
    : _injectedFactory = factory;
  static const maxEvents = 500;
  final DatabaseFactory? _injectedFactory;
  final String? databasePath;
  late final DatabaseFactory _factory =
      _injectedFactory ?? (kIsWeb ? databaseFactoryFfiWeb : databaseFactory);
  Future<Database>? _opening;

  Future<Database> _database() => _opening ??= _open();
  Future<Database> _open() async {
    final path =
        databasePath ??
        (kIsWeb
            ? 'whynot_application_errors.db'
            : '${await _factory.getDatabasesPath()}/whynot_application_errors.db');
    return _factory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (db, _) => db.execute(
          'CREATE TABLE error_outbox ('
          'event_id TEXT PRIMARY KEY, owner_id TEXT, occurred_at TEXT NOT NULL, payload TEXT NOT NULL)',
        ),
      ),
    );
  }

  @override
  Future<void> add(ApplicationErrorEvent event) async {
    await (await _database()).transaction((db) async {
      await db.insert('error_outbox', {
        'event_id': event.id,
        'owner_id': event.ownerId,
        'occurred_at': event.occurredAt.toUtc().toIso8601String(),
        'payload': jsonEncode(event.toLocalMap()),
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
      // Drop oldest records only when the device has exceeded its offline cap.
      await db.rawDelete(
        'DELETE FROM error_outbox WHERE event_id NOT IN '
        '(SELECT event_id FROM error_outbox ORDER BY occurred_at DESC, event_id DESC LIMIT ?)',
        [maxEvents],
      );
    });
  }

  @override
  Future<List<ApplicationErrorEvent>> pending(String userId) async {
    final rows = await (await _database()).query(
      'error_outbox',
      where: 'owner_id IS NULL OR owner_id = ?',
      whereArgs: [userId],
      orderBy: 'occurred_at, event_id',
      limit: 25,
    );
    return rows.map((row) {
      final data = Map<String, dynamic>.from(
        jsonDecode(row['payload'] as String) as Map,
      );
      data['ownerId'] = row['owner_id'];
      return ApplicationErrorEvent.fromLocalMap(data);
    }).toList();
  }

  @override
  Future<bool> claim(String eventId, String userId) async =>
      (await _database()).transaction((db) async {
        await db.update(
          'error_outbox',
          {'owner_id': userId},
          where: 'event_id = ? AND owner_id IS NULL',
          whereArgs: [eventId],
        );
        final rows = await db.query(
          'error_outbox',
          columns: ['owner_id'],
          where: 'event_id = ?',
          whereArgs: [eventId],
          limit: 1,
        );
        return rows.isNotEmpty && rows.first['owner_id'] == userId;
      });

  @override
  Future<void> remove(String eventId) async {
    await (await _database()).delete(
      'error_outbox',
      where: 'event_id = ?',
      whereArgs: [eventId],
    );
  }

  Future<void> close() async {
    if (_opening != null) await (await _opening!).close();
    _opening = null;
  }
}

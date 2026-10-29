import 'package:cloud_firestore/cloud_firestore.dart';

import '../../models/application_error_event.dart';
import '../../models/repositories/application_error_repository.dart';

class FirebaseApplicationErrorSink implements ApplicationErrorSink {
  FirebaseApplicationErrorSink({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;
  final FirebaseFirestore _firestore;

  @override
  Future<void> send(ApplicationErrorEvent event, String userId) async {
    final ref = _firestore.collection('applicationErrorEvents').doc(event.id);
    // Transactions fail offline instead of creating an unconfirmed SDK write.
    // Reusing the event ID makes retry safe even if a previous ACK was lost.
    await _firestore.runTransaction<void>(
      (transaction) async {
        final existing = await transaction.get(ref);
        if (existing.exists) return;
        transaction.set(ref, {
          'eventId': event.id,
          'schemaVersion': 1,
          'userId': userId,
          'occurredAt': Timestamp.fromDate(event.occurredAt),
          'createdAt': FieldValue.serverTimestamp(),
          'platform': event.platform,
          'feature': event.feature,
          'operation': event.operation,
          'code': event.code,
          'source': event.source,
        });
      },
      timeout: const Duration(seconds: 10),
      maxAttempts: 2,
    );
  }
}

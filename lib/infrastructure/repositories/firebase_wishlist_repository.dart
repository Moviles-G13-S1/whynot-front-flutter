import 'dart:async';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart'
    show kIsWeb, defaultTargetPlatform, TargetPlatform;

import '../../models/category.dart';
import '../../models/wishlist.dart';
import '../../models/repositories/wishlist_repository.dart';

class FirebaseWishlistRepository implements WishlistRepository {
  FirebaseWishlistRepository({
    FirebaseFirestore? firestore,
    FirebaseFunctions? functions,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _functions =
           functions ?? FirebaseFunctions.instanceFor(region: 'us-central1');

  final FirebaseFirestore _firestore;
  final FirebaseFunctions _functions;
  final Map<String, String> _pendingDeletes = {};

  String _operationId() {
    final random = Random.secure();
    return List.generate(
      16,
      (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
  }

  String get _platform => kIsWeb
      ? 'web'
      : defaultTargetPlatform == TargetPlatform.iOS
      ? 'ios'
      : 'android';

  Map<String, dynamic> _event({
    required String operationId,
    required String ownerId,
    required String action,
    required String outcome,
    required String reason,
    String? wishlistId,
    String? categoryId,
  }) => {
    'operationId': operationId,
    'userId': ownerId,
    'action': action,
    'outcome': outcome,
    'reason': reason,
    'platform': _platform,
    'schemaVersion': 1,
    'createdAt': FieldValue.serverTimestamp(),
    // ignore: use_null_aware_elements
    if (wishlistId != null) 'wishlistId': wishlistId,
    // ignore: use_null_aware_elements
    if (categoryId != null) 'categoryId': categoryId,
  };

  Future<void> _recordFailure({
    required String operationId,
    required String ownerId,
    required String action,
    String? wishlistId,
    String? categoryId,
  }) async {
    try {
      await _firestore
          .collection('wishlistInteractionEvents')
          .doc(operationId)
          .set(
            _event(
              operationId: operationId,
              ownerId: ownerId,
              action: action,
              outcome: 'failure',
              reason: 'unknown',
              wishlistId: wishlistId,
              categoryId: categoryId,
            ),
          );
    } catch (_) {
      /* A completed success or offline analytics remains authoritative. */
    }
  }

  @override
  Stream<List<Wishlist>> watchByOwner(String ownerId) => _firestore
      .collection('wishlists')
      .where('ownerId', isEqualTo: ownerId)
      .snapshots()
      .map((snapshot) => snapshot.docs.map(_fromDocument).toList());

  @override
  Future<List<Wishlist>> getByOwner(String ownerId) async {
    final snapshot = await _firestore
        .collection('wishlists')
        .where('ownerId', isEqualTo: ownerId)
        .get();
    return snapshot.docs.map(_fromDocument).toList();
  }

  @override
  Future<List<Category>> getCategories() async {
    final snapshot = await _firestore.collection('categories').get();
    return snapshot.docs
        .map(
          (document) => Category(
            id: document.id,
            name: document.data()['name'] as String? ?? document.id,
          ),
        )
        .toList();
  }

  @override
  Future<String> create({
    required String ownerId,
    required String categoryId,
    required String imageUrl,
    String? emoji,
  }) async {
    final document = _firestore.collection('wishlists').doc();
    final operationId = _operationId();
    final batch = _firestore.batch();
    batch.set(document, {
      'ownerId': ownerId,
      'categoryId': categoryId,
      'imageUrl': imageUrl,
      // ignore: use_null_aware_elements
      if (emoji != null) 'emoji': emoji,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    batch.set(
      _firestore.collection('wishlistInteractionEvents').doc(operationId),
      _event(
        operationId: operationId,
        ownerId: ownerId,
        action: 'create',
        outcome: 'success',
        reason: 'none',
        wishlistId: document.id,
        categoryId: categoryId,
      ),
    );
    try {
      await batch.commit();
    } catch (_) {
      unawaited(
        _recordFailure(
          operationId: operationId,
          ownerId: ownerId,
          action: 'create',
          wishlistId: document.id,
          categoryId: categoryId,
        ),
      );
      rethrow;
    }
    return document.id;
  }

  @override
  Future<void> updatePresentation({
    required String ownerId,
    required String wishlistId,
    required String imageUrl,
    String? emoji,
  }) async {
    final operationId = _operationId();
    try {
      final document = _firestore.collection('wishlists').doc(wishlistId);
      final current = await document.get();
      if (!current.exists || current.data()?['ownerId'] != ownerId) {
        throw StateError('Wishlist not found.');
      }
      final batch = _firestore.batch();
      batch.update(document, {
        'imageUrl': imageUrl,
        'emoji': emoji ?? FieldValue.delete(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      batch.set(
        _firestore.collection('wishlistInteractionEvents').doc(operationId),
        _event(
          operationId: operationId,
          ownerId: ownerId,
          action: 'edit',
          outcome: 'success',
          reason: 'none',
          wishlistId: wishlistId,
          categoryId: current.data()?['categoryId'] as String?,
        ),
      );
      await batch.commit();
    } catch (_) {
      unawaited(
        _recordFailure(
          operationId: operationId,
          ownerId: ownerId,
          action: 'edit',
          wishlistId: wishlistId,
        ),
      );
      rethrow;
    }
  }

  @override
  Future<({String outcome, String reason})> deleteEmpty({
    required String ownerId,
    required String wishlistId,
  }) async {
    final operationId = _pendingDeletes.putIfAbsent(wishlistId, _operationId);
    final result = await _functions.httpsCallable('delete_empty_wishlist').call(
      {
        'wishlistId': wishlistId,
        'operationId': operationId,
        'platform': _platform,
      },
    );
    final data = Map<String, dynamic>.from(result.data as Map);
    _pendingDeletes.remove(wishlistId);
    return (
      outcome: data['outcome'] as String,
      reason: data['reason'] as String,
    );
  }

  @override
  Future<void> trackInteraction({
    required String ownerId,
    required String action,
    required String outcome,
    required String reason,
    String? wishlistId,
    String? categoryId,
  }) async {
    final operationId = _operationId();
    await _firestore
        .collection('wishlistInteractionEvents')
        .doc(operationId)
        .set(
          _event(
            operationId: operationId,
            ownerId: ownerId,
            action: action,
            outcome: outcome,
            reason: reason,
            wishlistId: wishlistId,
            categoryId: categoryId,
          ),
        );
  }

  Wishlist _fromDocument(QueryDocumentSnapshot<Map<String, dynamic>> document) {
    final data = document.data();
    return Wishlist(
      id: document.id,
      ownerId: data['ownerId'] as String? ?? '',
      categoryId: data['categoryId'] as String? ?? '',
      imageUrl: data['imageUrl'] as String? ?? '',
      emoji: data['emoji'] as String?,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }
}

import 'package:cloud_firestore/cloud_firestore.dart';

import '../../models/user_profile.dart';
import '../../models/repositories/user_repository.dart';

class FirebaseUserRepository implements UserRepository {
  FirebaseUserRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  @override
  Stream<UserProfile?> watch(String userId) => _firestore
      .collection('users')
      .doc(userId)
      .snapshots()
      .map((document) => _fromDocument(document));

  @override
  Stream<List<UserProfile>> watchAll() => _firestore
      .collection('users')
      .snapshots()
      .map(
        (snapshot) =>
            snapshot.docs.map(_fromDocument).whereType<UserProfile>().toList(),
      );

  @override
  Future<UserProfile?> get(String userId) async {
    final document = await _firestore.collection('users').doc(userId).get();
    return _fromDocument(document);
  }

  @override
  Future<void> create(UserProfile profile) =>
      _firestore.collection('users').doc(profile.id).set({
        'name': profile.name,
        'email': profile.email,
        'gender': profile.gender,
        'age': profile.age,
        'preferredCategoryId': profile.preferredCategoryId,
        'cityId': profile.cityId,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

  @override
  Future<void> update(String userId, UserProfileUpdate update) =>
      _firestore.collection('users').doc(userId).update({
        'name': update.name,
        'gender': update.gender,
        'age': update.age,
        'preferredCategoryId': update.preferredCategoryId,
        'cityId': update.cityId,
        'updatedAt': FieldValue.serverTimestamp(),
      });

  @override
  // Santiago Casasbuenas: Persist the private Storage path on the user profile.
  Future<void> updatePhotoPath(String userId, String path) => _firestore
      .collection('users')
      .doc(userId)
      .update({'photoPath': path, 'updatedAt': FieldValue.serverTimestamp()});

  // Santiago Casasbuenas: Include the saved photo path when reading profiles.
  UserProfile? _fromDocument(DocumentSnapshot<Map<String, dynamic>> document) {
    final data = document.data();
    if (data == null) return null;

    return UserProfile(
      id: document.id,
      name: data['name'] as String? ?? '',
      email: data['email'] as String? ?? '',
      gender: data['gender'] as String? ?? '',
      age: (data['age'] as num?)?.toInt() ?? 0,
      preferredCategoryId: data['preferredCategoryId'] as String? ?? '',
      cityId: data['cityId'] as String?,
      photoPath: data['photoPath'] as String?,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }
}

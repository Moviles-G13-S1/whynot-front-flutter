import 'package:cloud_firestore/cloud_firestore.dart';

import '../domain/user_profile.dart';
import '../domain/user_repository.dart';

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
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }
}

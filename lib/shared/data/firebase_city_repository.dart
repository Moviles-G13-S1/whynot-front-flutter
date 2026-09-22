import 'package:cloud_firestore/cloud_firestore.dart';

import '../domain/city.dart';
import '../domain/city_repository.dart';

class FirebaseCityRepository implements CityRepository {
  FirebaseCityRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  @override
  Future<List<City>> getCities() async {
    final snapshot = await _firestore.collection('cities').get();
    final cities = snapshot.docs
        .map(
          (doc) =>
              City(id: doc.id, name: doc.data()['name'] as String? ?? doc.id),
        )
        .toList();
    cities.sort((a, b) {
      if (a.id == 'other') return 1;
      if (b.id == 'other') return -1;
      return a.name.compareTo(b.name);
    });
    return cities;
  }
}

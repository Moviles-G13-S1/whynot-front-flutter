import 'city.dart';

abstract interface class CityRepository {
  Future<List<City>> getCities();
}

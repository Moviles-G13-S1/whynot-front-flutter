import '../models/city.dart';
import '../models/repositories/city_repository.dart';

/// Provides the city catalog to views without exposing its data source.
class CityController {
  const CityController({required CityRepository cityRepository})
    : _cityRepository = cityRepository;

  final CityRepository _cityRepository;

  Future<List<City>> getCities() =>
      _cityRepository.getCities().timeout(const Duration(seconds: 12));
}

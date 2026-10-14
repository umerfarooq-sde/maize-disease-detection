import '../datasources/fertilizer_datasource.dart';
import '../models/fertilizer_models.dart';

abstract interface class FertilizerRepository {
  Future<FertilizerCatalogue> rules();
  Future<FertilizerResult> calculate(FertilizerInput input);
}

class ApiFertilizerRepository implements FertilizerRepository {
  const ApiFertilizerRepository(this._remote);
  final FertilizerDatasource _remote;
  @override
  Future<FertilizerCatalogue> rules() => _remote.rules();
  @override
  Future<FertilizerResult> calculate(FertilizerInput input) =>
      _remote.calculate(input);
}

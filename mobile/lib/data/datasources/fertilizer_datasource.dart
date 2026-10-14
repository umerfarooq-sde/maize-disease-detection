import '../../core/exceptions/app_exception.dart';
import '../../core/network/api_client.dart';
import '../models/fertilizer_models.dart';

class FertilizerDatasource {
  const FertilizerDatasource(this._api);
  final ApiClient _api;

  Future<FertilizerCatalogue> rules() async {
    final response = await _api.get('calculators/fertilizer/rules');
    return FertilizerCatalogue.fromJson(response.data);
  }

  Future<FertilizerResult> calculate(FertilizerInput input) async {
    final response = await _api.request(
      ApiMethod.post,
      'calculators/fertilizer/calculate',
      body: input.toJson(),
    );
    final result = FertilizerResult.fromJson(response.data);
    if (!result.matches(input)) {
      throw const AppException(AppErrorKind.invalidResponse);
    }
    return result;
  }
}

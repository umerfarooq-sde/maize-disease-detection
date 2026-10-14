import '../../core/exceptions/app_exception.dart';
import '../../core/network/api_client.dart';
import '../models/yield_models.dart';

abstract interface class YieldRepository {
  Future<YieldCatalogue> configurations();
  Future<YieldResult> calculate(YieldInput input);
}

class ApiYieldRepository implements YieldRepository {
  const ApiYieldRepository(this._api);
  final ApiClient _api;
  @override
  Future<YieldCatalogue> configurations() async => YieldCatalogue.fromJson(
    (await _api.get('calculators/yield/configurations')).data,
  );
  @override
  Future<YieldResult> calculate(YieldInput input) async {
    final result = YieldResult.fromJson(
      (await _api.request(
        ApiMethod.post,
        'calculators/yield/calculate',
        body: input.toJson(),
      )).data,
    );
    if (!result.matches(input)) {
      throw const AppException(AppErrorKind.invalidResponse);
    }
    return result;
  }
}

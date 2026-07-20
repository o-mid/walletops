import '../../../core/error/error_mapper.dart';
import '../domain/demo_repository.dart';
import 'demo_api.dart';
import 'demo_models.dart';

class DemoRepositoryImpl implements DemoRepository {
  DemoRepositoryImpl(this._api);

  final DemoApi _api;

  @override
  Future<DemoSimulateResult> simulate({
    int count = 1,
    bool ensureDemoRule = true,
  }) {
    return guardApi(
      () => _api.simulate(count: count, ensureDemoRule: ensureDemoRule),
    );
  }
}

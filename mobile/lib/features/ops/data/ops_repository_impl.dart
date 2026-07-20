import '../../../core/error/error_mapper.dart';
import '../domain/ops_repository.dart';
import 'health_api.dart';
import 'health_models.dart';

class OpsRepositoryImpl implements OpsRepository {
  OpsRepositoryImpl(this._api);

  final HealthApi _api;

  @override
  Future<OpsHealth> fetchHealth() => guardApi(_api.fetch);
}

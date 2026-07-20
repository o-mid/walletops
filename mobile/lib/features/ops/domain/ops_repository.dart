import '../data/health_models.dart';

abstract class OpsRepository {
  Future<OpsHealth> fetchHealth();
}

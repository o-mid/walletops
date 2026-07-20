import '../../../core/error/error_mapper.dart';
import '../domain/rules_repository.dart';
import 'rule_models.dart';
import 'rules_api.dart';

class RulesRepositoryImpl implements RulesRepository {
  RulesRepositoryImpl(this._api);

  final RulesApi _api;

  @override
  Future<List<AlertRule>> list() => guardApi(_api.list);

  @override
  Future<AlertRule> create({
    required String name,
    required String eventType,
    double? threshold,
    bool enabled = true,
  }) {
    return guardApi(
      () => _api.create(
        name: name,
        eventType: eventType,
        threshold: threshold,
        enabled: enabled,
      ),
    );
  }

  @override
  Future<AlertRule> update({
    required String id,
    String? name,
    String? eventType,
    double? threshold,
    bool clearThreshold = false,
    bool? enabled,
  }) {
    return guardApi(
      () => _api.update(
        id: id,
        name: name,
        eventType: eventType,
        threshold: threshold,
        clearThreshold: clearThreshold,
        enabled: enabled,
      ),
    );
  }

  @override
  Future<void> delete(String id) => guardApi(() => _api.delete(id));
}

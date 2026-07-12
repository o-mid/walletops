import 'rule_models.dart';
import 'rules_api.dart';

class RulesRepository {
  RulesRepository(this._api);

  final RulesApi _api;

  Future<List<AlertRule>> list() => _api.list();

  Future<AlertRule> create({
    required String name,
    required String eventType,
    double? threshold,
    bool enabled = true,
  }) =>
      _api.create(
        name: name,
        eventType: eventType,
        threshold: threshold,
        enabled: enabled,
      );

  Future<AlertRule> update({
    required String id,
    String? name,
    String? eventType,
    double? threshold,
    bool clearThreshold = false,
    bool? enabled,
  }) =>
      _api.update(
        id: id,
        name: name,
        eventType: eventType,
        threshold: threshold,
        clearThreshold: clearThreshold,
        enabled: enabled,
      );

  Future<void> delete(String id) => _api.delete(id);
}

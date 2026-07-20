import '../data/rule_models.dart';

abstract class RulesRepository {
  Future<List<AlertRule>> list();

  Future<AlertRule> create({
    required String name,
    required String eventType,
    double? threshold,
    bool enabled = true,
  });

  Future<AlertRule> update({
    required String id,
    String? name,
    String? eventType,
    double? threshold,
    bool clearThreshold = false,
    bool? enabled,
  });

  Future<void> delete(String id);
}

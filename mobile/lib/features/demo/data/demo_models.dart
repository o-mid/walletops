import '../../events/data/event_models.dart';

class DemoSimulateResult {
  const DemoSimulateResult({
    required this.events,
    required this.demoRuleCreated,
    required this.hint,
    this.demoRuleId,
  });

  final List<OpsEvent> events;
  final String? demoRuleId;
  final bool demoRuleCreated;
  final String hint;
}

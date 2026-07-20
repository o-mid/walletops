import '../data/summary_models.dart';

abstract class ExplainRepository {
  Future<EventSummary> summarize(List<String> eventIds);
}

import 'ai_api.dart';
import 'summary_models.dart';

class ExplainRepository {
  ExplainRepository(this._api);

  final AiApi _api;

  Future<EventSummary> summarize(List<String> eventIds) =>
      _api.summarize(eventIds);
}

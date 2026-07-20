import '../../../core/error/error_mapper.dart';
import '../domain/explain_repository.dart';
import 'ai_api.dart';
import 'summary_models.dart';

class ExplainRepositoryImpl implements ExplainRepository {
  ExplainRepositoryImpl(this._api);

  final AiApi _api;

  @override
  Future<EventSummary> summarize(List<String> eventIds) =>
      guardApi(() => _api.summarize(eventIds));
}

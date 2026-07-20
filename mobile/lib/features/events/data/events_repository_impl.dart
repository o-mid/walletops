import '../../../core/error/error_mapper.dart';
import '../domain/events_repository.dart';
import 'event_models.dart';
import 'events_api.dart';

class EventsRepositoryImpl implements EventsRepository {
  EventsRepositoryImpl(this._api);

  final EventsApi _api;

  @override
  Future<List<OpsEvent>> list({String? status}) =>
      guardApi(() => _api.list(status: status));

  @override
  Future<OpsEvent> getById(String id) => guardApi(() => _api.getById(id));
}

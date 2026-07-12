import 'event_models.dart';
import 'events_api.dart';

class EventsRepository {
  EventsRepository(this._api);

  final EventsApi _api;

  Future<List<OpsEvent>> list({String? status}) => _api.list(status: status);

  Future<OpsEvent> getById(String id) => _api.getById(id);
}

import '../data/event_models.dart';

abstract class EventsRepository {
  Future<List<OpsEvent>> list({String? status});

  Future<OpsEvent> getById(String id);
}

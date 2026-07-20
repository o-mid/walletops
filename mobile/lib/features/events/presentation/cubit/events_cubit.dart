import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/error/error_mapper.dart';
import '../../domain/events_repository.dart';
import 'events_state.dart';

class EventsCubit extends Cubit<EventsState> {
  EventsCubit(this._repo) : super(const EventsState());

  final EventsRepository _repo;

  Future<void> load({String? status, bool updateFilter = false}) async {
    final filter = updateFilter ? status : (status ?? state.filter);
    emit(
      EventsState(
        status: EventsStatus.loading,
        items: state.items,
        filter: filter,
      ),
    );
    try {
      final items = await _repo.list(status: filter);
      if (items.isEmpty) {
        emit(EventsState(status: EventsStatus.empty, filter: filter));
        return;
      }
      emit(
        EventsState(
          status: EventsStatus.ready,
          items: items,
          filter: filter,
        ),
      );
    } catch (e) {
      emit(
        EventsState(
          status: EventsStatus.error,
          filter: filter,
          errorMessage: mapError(e).message,
        ),
      );
    }
  }

  Future<void> refresh() => load();

  Future<void> setFilter(String? status) =>
      load(status: status, updateFilter: true);
}

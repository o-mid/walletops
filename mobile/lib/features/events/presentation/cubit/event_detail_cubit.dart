import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/error/error_mapper.dart';
import '../../domain/events_repository.dart';
import 'event_detail_state.dart';

class EventDetailCubit extends Cubit<EventDetailState> {
  EventDetailCubit(this._repo) : super(const EventDetailState());

  final EventsRepository _repo;

  Future<void> load(String id) async {
    emit(state.copyWith(status: EventDetailStatus.loading, clearError: true));
    try {
      final event = await _repo.getById(id);
      emit(state.copyWith(status: EventDetailStatus.ready, event: event));
    } catch (e) {
      emit(
        state.copyWith(
          status: EventDetailStatus.error,
          errorMessage: mapError(e).message,
        ),
      );
    }
  }
}

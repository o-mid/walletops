import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/error/error_mapper.dart';
import '../../domain/events_repository.dart';
import 'event_detail_state.dart';

class EventDetailCubit extends Cubit<EventDetailState> {
  EventDetailCubit(this._repo) : super(const EventDetailState());

  final EventsRepository _repo;
  Timer? _poll;
  String? _watchingId;

  Future<void> load(String id) async {
    _watchingId = id;
    final quiet = state.event?.id == id &&
        (state.event?.status == 'pending' ||
            state.event?.status == 'processing');
    if (!quiet) {
      emit(state.copyWith(status: EventDetailStatus.loading, clearError: true));
    }
    try {
      final event = await _repo.getById(id);
      emit(state.copyWith(status: EventDetailStatus.ready, event: event));
      _syncPoll(event.status);
    } catch (e) {
      emit(
        state.copyWith(
          status: EventDetailStatus.error,
          errorMessage: mapError(e).message,
        ),
      );
      _stopPoll();
    }
  }

  void _syncPoll(String status) {
    final active = status == 'pending' || status == 'processing';
    if (!active) {
      _stopPoll();
      return;
    }
    if (_poll != null) {
      return;
    }
    _poll = Timer.periodic(const Duration(seconds: 1), (_) {
      final id = _watchingId;
      if (id != null) {
        unawaited(load(id));
      }
    });
  }

  void _stopPoll() {
    _poll?.cancel();
    _poll = null;
  }

  @override
  Future<void> close() {
    _stopPoll();
    return super.close();
  }
}

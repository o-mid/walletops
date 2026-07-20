import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/error/error_mapper.dart';
import '../../../demo/domain/demo_repository.dart';
import '../../domain/events_repository.dart';
import 'events_state.dart';

class EventsCubit extends Cubit<EventsState> {
  EventsCubit(this._repo, this._demo) : super(const EventsState());

  final EventsRepository _repo;
  final DemoRepository _demo;
  Timer? _liveTimer;

  Future<void> load({String? status, bool updateFilter = false}) async {
    final filter = updateFilter ? status : (status ?? state.filter);
    final quiet = state.liveWatching || state.demoBusy;
    if (!quiet) {
      emit(
        state.copyWith(
          status: EventsStatus.loading,
          clearError: true,
        ),
      );
    }
    try {
      final items = await _repo.list(status: filter);
      if (items.isEmpty) {
        emit(
          state.copyWith(
            status: EventsStatus.empty,
            items: const [],
            filter: filter,
            clearError: true,
          ),
        );
        _syncLiveWatch();
        return;
      }
      emit(
        state.copyWith(
          status: EventsStatus.ready,
          items: items,
          filter: filter,
          clearError: true,
        ),
      );
      _syncLiveWatch();
    } catch (e) {
      emit(
        state.copyWith(
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

  void startLiveWatch() {
    if (state.liveWatching) {
      return;
    }
    emit(state.copyWith(liveWatching: true));
    _liveTimer?.cancel();
    _liveTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      unawaited(load());
    });
  }

  void stopLiveWatch() {
    _liveTimer?.cancel();
    _liveTimer = null;
    if (state.liveWatching) {
      emit(state.copyWith(liveWatching: false));
    }
  }

  void _syncLiveWatch() {
    if (state.demoBusy) {
      return;
    }
    if (state.hasActiveQueue) {
      startLiveWatch();
    } else if (state.liveWatching && !state.demoBusy) {
      stopLiveWatch();
    }
  }

  /// Injects events one-by-one so the user can watch PENDING → PROCESSING → PROCESSED.
  Future<void> runGuidedDemo({int eventCount = 3}) async {
    if (state.demoBusy) {
      return;
    }
    emit(
      state.copyWith(
        demoBusy: true,
        liveWatching: true,
        journeyMessage: 'Preparing demo rule and live refresh…',
        clearError: true,
      ),
    );
    startLiveWatch();

    try {
      for (var i = 0; i < eventCount; i++) {
        emit(
          state.copyWith(
            journeyMessage:
                'Injecting webhook ${i + 1} of $eventCount as PENDING…',
          ),
        );
        final result = await _demo.simulate(
          count: 1,
          ensureDemoRule: i == 0,
        );
        final created = result.events.isEmpty ? null : result.events.first;
        final ruleNote = result.demoRuleCreated
            ? ' Created “Demo balance watch” rule.'
            : '';
        emit(
          state.copyWith(
            journeyMessage: created == null
                ? 'Webhook ${i + 1} sent.$ruleNote'
                : 'Webhook ${i + 1}: ${created.type} is ${created.status.toUpperCase()}.$ruleNote '
                    'Watch status move to PROCESSING then PROCESSED.',
          ),
        );
        await load();
        if (created != null) {
          await _waitUntilTerminal(created.id);
        } else {
          await Future<void>.delayed(const Duration(seconds: 5));
        }
      }
      emit(
        state.copyWith(
          demoBusy: false,
          journeyMessage:
              'Demo complete. Open a PROCESSED event for the pipeline steps, then Explain.',
        ),
      );
      await load();
      _syncLiveWatch();
    } catch (e) {
      emit(
        state.copyWith(
          demoBusy: false,
          errorMessage: mapError(e).message,
          clearJourney: true,
        ),
      );
      stopLiveWatch();
    }
  }

  Future<void> _waitUntilTerminal(String eventId) async {
    final deadline = DateTime.now().add(const Duration(seconds: 20));
    while (DateTime.now().isBefore(deadline) && !isClosed) {
      await Future<void>.delayed(const Duration(milliseconds: 800));
      await load();
      final match = state.items.where((e) => e.id == eventId);
      if (match.isEmpty) {
        continue;
      }
      final status = match.first.status;
      if (status == 'processed' || status == 'failed') {
        return;
      }
      emit(
        state.copyWith(
          journeyMessage:
              'Live: ${match.first.type} is ${status.toUpperCase()} — worker claim / rule match in progress…',
        ),
      );
    }
  }

  @override
  Future<void> close() {
    _liveTimer?.cancel();
    return super.close();
  }
}

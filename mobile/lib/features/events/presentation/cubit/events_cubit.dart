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

  static const _betweenEventsPause = Duration(milliseconds: 700);
  static const _terminalWait = Duration(seconds: 25);

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
    if (state.liveWatching && _liveTimer != null) {
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

  Future<void> runGuidedDemo({int eventCount = 3}) async {
    if (state.demoBusy) {
      return;
    }
    emit(
      state.copyWith(
        demoBusy: true,
        liveWatching: true,
        demoStep: 0,
        demoTotal: eventCount,
        journeyMessage: 'Preparing demo rule and live refresh…',
        clearError: true,
      ),
    );
    startLiveWatch();

    try {
      for (var i = 0; i < eventCount; i++) {
        emit(
          state.copyWith(
            demoStep: i,
            journeyMessage:
                'Step ${i + 1}/$eventCount — injecting webhook as PENDING…',
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
            demoStep: i,
            journeyMessage: created == null
                ? 'Webhook ${i + 1} sent.$ruleNote'
                : 'Step ${i + 1}/$eventCount — ${created.type} is '
                    '${created.status.toUpperCase()}.$ruleNote '
                    'Watch PENDING → PROCESSING → PROCESSED.',
          ),
        );
        await load();
        if (created != null) {
          await _waitUntilTerminal(created.id, step: i + 1, total: eventCount);
        } else {
          await Future<void>.delayed(const Duration(seconds: 8));
        }
        if (i < eventCount - 1) {
          emit(
            state.copyWith(
              demoStep: i + 1,
              journeyMessage:
                  'Step ${i + 1}/$eventCount done. Pausing before the next webhook…',
            ),
          );
          await Future<void>.delayed(_betweenEventsPause);
        }
      }
      emit(
        state.copyWith(
          demoBusy: false,
          demoStep: eventCount,
          demoTotal: eventCount,
          journeyMessage:
              'Demo complete. Open a PROCESSED event for pipeline detail, then Explain.',
        ),
      );
      await load();
      _syncLiveWatch();
    } catch (e) {
      emit(
        state.copyWith(
          demoBusy: false,
          demoStep: 0,
          demoTotal: 0,
          errorMessage: mapError(e).message,
          clearJourney: true,
        ),
      );
      stopLiveWatch();
    }
  }

  Future<void> _waitUntilTerminal(
    String eventId, {
    required int step,
    required int total,
  }) async {
    final deadline = DateTime.now().add(_terminalWait);
    while (DateTime.now().isBefore(deadline) && !isClosed) {
      await Future<void>.delayed(const Duration(milliseconds: 900));
      await load();
      final match = state.items.where((e) => e.id == eventId);
      if (match.isEmpty) {
        continue;
      }
      final current = match.first;
      final status = current.status;
      if (status == 'processed' || status == 'failed') {
        emit(
          state.copyWith(
            demoStep: step,
            journeyMessage:
                'Step $step/$total — ${current.type} finished as ${status.toUpperCase()}.',
          ),
        );
        return;
      }
      emit(
        state.copyWith(
          journeyMessage:
              'Step $step/$total — ${current.type} is ${status.toUpperCase()} '
              '(worker claim / rule match in progress)…',
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

import 'package:equatable/equatable.dart';

import '../../data/event_models.dart';

enum EventsStatus { initial, loading, ready, empty, error }

class EventsState extends Equatable {
  const EventsState({
    this.status = EventsStatus.initial,
    this.items = const [],
    this.filter,
    this.errorMessage,
    this.liveWatching = false,
    this.demoBusy = false,
    this.journeyMessage,
    this.demoStep = 0,
    this.demoTotal = 0,
  });

  final EventsStatus status;
  final List<OpsEvent> items;
  final String? filter;
  final String? errorMessage;
  final bool liveWatching;
  final bool demoBusy;
  final String? journeyMessage;
  final int demoStep;
  final int demoTotal;

  bool get hasActiveQueue =>
      items.any((e) => e.status == 'pending' || e.status == 'processing');

  double get demoProgress {
    if (demoTotal <= 0) {
      return 0;
    }
    return (demoStep / demoTotal).clamp(0.0, 1.0);
  }

  EventsState copyWith({
    EventsStatus? status,
    List<OpsEvent>? items,
    String? filter,
    String? errorMessage,
    bool? liveWatching,
    bool? demoBusy,
    String? journeyMessage,
    int? demoStep,
    int? demoTotal,
    bool clearFilter = false,
    bool clearError = false,
    bool clearJourney = false,
  }) {
    return EventsState(
      status: status ?? this.status,
      items: items ?? this.items,
      filter: clearFilter ? null : (filter ?? this.filter),
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      liveWatching: liveWatching ?? this.liveWatching,
      demoBusy: demoBusy ?? this.demoBusy,
      journeyMessage:
          clearJourney ? null : (journeyMessage ?? this.journeyMessage),
      demoStep: demoStep ?? this.demoStep,
      demoTotal: demoTotal ?? this.demoTotal,
    );
  }

  @override
  List<Object?> get props => [
        status,
        items,
        filter,
        errorMessage,
        liveWatching,
        demoBusy,
        journeyMessage,
        demoStep,
        demoTotal,
      ];
}

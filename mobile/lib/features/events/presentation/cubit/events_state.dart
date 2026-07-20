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
  });

  final EventsStatus status;
  final List<OpsEvent> items;
  final String? filter;
  final String? errorMessage;
  final bool liveWatching;
  final bool demoBusy;
  final String? journeyMessage;

  bool get hasActiveQueue =>
      items.any((e) => e.status == 'pending' || e.status == 'processing');

  EventsState copyWith({
    EventsStatus? status,
    List<OpsEvent>? items,
    String? filter,
    String? errorMessage,
    bool? liveWatching,
    bool? demoBusy,
    String? journeyMessage,
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
      ];
}

import 'package:equatable/equatable.dart';

import '../../data/event_models.dart';

enum EventsStatus { initial, loading, ready, empty, error }

class EventsState extends Equatable {
  const EventsState({
    this.status = EventsStatus.initial,
    this.items = const [],
    this.filter,
    this.errorMessage,
  });

  final EventsStatus status;
  final List<OpsEvent> items;
  final String? filter;
  final String? errorMessage;

  EventsState copyWith({
    EventsStatus? status,
    List<OpsEvent>? items,
    String? filter,
    String? errorMessage,
    bool clearFilter = false,
    bool clearError = false,
  }) {
    return EventsState(
      status: status ?? this.status,
      items: items ?? this.items,
      filter: clearFilter ? null : (filter ?? this.filter),
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }

  @override
  List<Object?> get props => [status, items, filter, errorMessage];
}

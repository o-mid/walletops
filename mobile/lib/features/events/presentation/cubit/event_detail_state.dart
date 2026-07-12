import 'package:equatable/equatable.dart';

import '../../data/event_models.dart';

enum EventDetailStatus { initial, loading, ready, error }

class EventDetailState extends Equatable {
  const EventDetailState({
    this.status = EventDetailStatus.initial,
    this.event,
    this.errorMessage,
  });

  final EventDetailStatus status;
  final OpsEvent? event;
  final String? errorMessage;

  EventDetailState copyWith({
    EventDetailStatus? status,
    OpsEvent? event,
    String? errorMessage,
    bool clearError = false,
  }) {
    return EventDetailState(
      status: status ?? this.status,
      event: event ?? this.event,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }

  @override
  List<Object?> get props => [status, event, errorMessage];
}

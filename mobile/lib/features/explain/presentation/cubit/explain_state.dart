import 'package:equatable/equatable.dart';

import '../../data/summary_models.dart';

enum ExplainStatus { initial, loading, ready, error }

class ExplainState extends Equatable {
  const ExplainState({
    this.status = ExplainStatus.initial,
    this.summary,
    this.errorMessage,
    this.eventIds = const [],
  });

  final ExplainStatus status;
  final EventSummary? summary;
  final String? errorMessage;
  final List<String> eventIds;

  ExplainState copyWith({
    ExplainStatus? status,
    EventSummary? summary,
    String? errorMessage,
    List<String>? eventIds,
    bool clearError = false,
  }) {
    return ExplainState(
      status: status ?? this.status,
      summary: summary ?? this.summary,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      eventIds: eventIds ?? this.eventIds,
    );
  }

  @override
  List<Object?> get props => [status, summary, errorMessage, eventIds];
}

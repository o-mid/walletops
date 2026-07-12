import 'package:equatable/equatable.dart';

import '../../data/rule_models.dart';

enum RulesStatus { initial, loading, ready, empty, error }

class RulesState extends Equatable {
  const RulesState({
    this.status = RulesStatus.initial,
    this.items = const [],
    this.errorMessage,
    this.busy = false,
  });

  final RulesStatus status;
  final List<AlertRule> items;
  final String? errorMessage;
  final bool busy;

  RulesState copyWith({
    RulesStatus? status,
    List<AlertRule>? items,
    String? errorMessage,
    bool? busy,
    bool clearError = false,
  }) {
    return RulesState(
      status: status ?? this.status,
      items: items ?? this.items,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      busy: busy ?? this.busy,
    );
  }

  @override
  List<Object?> get props => [status, items, errorMessage, busy];
}

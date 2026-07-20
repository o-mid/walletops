import 'package:equatable/equatable.dart';

import '../../data/health_models.dart';

enum OpsHealthStatus { idle, loading, ready, error }

class OpsHealthState extends Equatable {
  const OpsHealthState({
    this.status = OpsHealthStatus.idle,
    this.health,
    this.errorMessage,
  });

  final OpsHealthStatus status;
  final OpsHealth? health;
  final String? errorMessage;

  bool get ok => health?.ok == true && status == OpsHealthStatus.ready;

  OpsHealthState copyWith({
    OpsHealthStatus? status,
    OpsHealth? health,
    String? errorMessage,
    bool clearError = false,
  }) {
    return OpsHealthState(
      status: status ?? this.status,
      health: health ?? this.health,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }

  @override
  List<Object?> get props => [status, health, errorMessage];
}

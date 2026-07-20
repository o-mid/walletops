import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/error/error_mapper.dart';
import '../../domain/ops_repository.dart';
import 'ops_health_state.dart';

class OpsHealthCubit extends Cubit<OpsHealthState> {
  OpsHealthCubit(this._repo) : super(const OpsHealthState());

  final OpsRepository _repo;
  Timer? _timer;

  void start({Duration interval = const Duration(seconds: 4)}) {
    _timer?.cancel();
    unawaited(refresh());
    _timer = Timer.periodic(interval, (_) => unawaited(refresh()));
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
    emit(const OpsHealthState());
  }

  Future<void> refresh() async {
    if (state.status == OpsHealthStatus.idle ||
        state.status == OpsHealthStatus.error) {
      emit(state.copyWith(status: OpsHealthStatus.loading, clearError: true));
    }
    try {
      final health = await _repo.fetchHealth();
      emit(
        OpsHealthState(
          status: OpsHealthStatus.ready,
          health: health,
        ),
      );
    } catch (e) {
      emit(
        OpsHealthState(
          status: OpsHealthStatus.error,
          health: state.health,
          errorMessage: mapError(e).message,
        ),
      );
    }
  }

  @override
  Future<void> close() {
    _timer?.cancel();
    return super.close();
  }
}

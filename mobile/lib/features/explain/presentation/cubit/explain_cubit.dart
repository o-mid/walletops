import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/error/error_mapper.dart';
import '../../domain/explain_repository.dart';
import 'explain_state.dart';

class ExplainCubit extends Cubit<ExplainState> {
  ExplainCubit(this._repo) : super(const ExplainState());

  final ExplainRepository _repo;

  Future<void> load(List<String> eventIds) async {
    if (eventIds.isEmpty) {
      emit(
        const ExplainState(
          status: ExplainStatus.error,
          errorMessage: 'No events selected',
        ),
      );
      return;
    }
    emit(
      ExplainState(
        status: ExplainStatus.loading,
        eventIds: eventIds,
      ),
    );
    try {
      final summary = await _repo.summarize(eventIds);
      emit(
        ExplainState(
          status: ExplainStatus.ready,
          summary: summary,
          eventIds: eventIds,
        ),
      );
    } catch (e) {
      emit(
        ExplainState(
          status: ExplainStatus.error,
          eventIds: eventIds,
          errorMessage: mapError(e).message,
        ),
      );
    }
  }

  Future<void> retry() => load(state.eventIds);
}

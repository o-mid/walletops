import 'package:dio/dio.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/explain_repository.dart';
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
          errorMessage: _message(e),
        ),
      );
    }
  }

  Future<void> retry() => load(state.eventIds);

  String _message(Object e) {
    if (e is DioException) {
      final data = e.response?.data;
      if (data is Map && data['error'] is Map) {
        final msg = data['error']['message'];
        if (msg is String && msg.isNotEmpty) {
          return msg;
        }
      }
      return 'Failed to summarize events';
    }
    return 'Something went wrong';
  }
}

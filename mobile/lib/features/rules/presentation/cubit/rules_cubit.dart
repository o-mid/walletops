import 'package:dio/dio.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/rules_repository.dart';
import 'rules_state.dart';

class RulesCubit extends Cubit<RulesState> {
  RulesCubit(this._repo) : super(const RulesState());

  final RulesRepository _repo;

  Future<void> load() async {
    emit(state.copyWith(status: RulesStatus.loading, clearError: true));
    try {
      final items = await _repo.list();
      if (items.isEmpty) {
        emit(const RulesState(status: RulesStatus.empty));
        return;
      }
      emit(RulesState(status: RulesStatus.ready, items: items));
    } catch (e) {
      emit(
        RulesState(
          status: RulesStatus.error,
          errorMessage: _message(e),
        ),
      );
    }
  }

  Future<void> refresh() => load();

  Future<bool> create({
    required String name,
    required String eventType,
    double? threshold,
    bool enabled = true,
  }) async {
    emit(state.copyWith(busy: true, clearError: true));
    try {
      await _repo.create(
        name: name,
        eventType: eventType,
        threshold: threshold,
        enabled: enabled,
      );
      await load();
      return true;
    } catch (e) {
      emit(state.copyWith(busy: false, errorMessage: _message(e)));
      return false;
    }
  }

  Future<bool> update({
    required String id,
    required String name,
    required String eventType,
    double? threshold,
    bool clearThreshold = false,
    required bool enabled,
  }) async {
    emit(state.copyWith(busy: true, clearError: true));
    try {
      await _repo.update(
        id: id,
        name: name,
        eventType: eventType,
        threshold: threshold,
        clearThreshold: clearThreshold,
        enabled: enabled,
      );
      await load();
      return true;
    } catch (e) {
      emit(state.copyWith(busy: false, errorMessage: _message(e)));
      return false;
    }
  }

  Future<void> remove(String id) async {
    emit(state.copyWith(busy: true, clearError: true));
    try {
      await _repo.delete(id);
      await load();
    } catch (e) {
      emit(state.copyWith(busy: false, errorMessage: _message(e)));
    }
  }

  String _message(Object e) {
    if (e is DioException) {
      final data = e.response?.data;
      if (data is Map && data['error'] is Map) {
        final msg = data['error']['message'];
        if (msg is String && msg.isNotEmpty) {
          return msg;
        }
      }
      return 'Request failed';
    }
    return 'Something went wrong';
  }
}

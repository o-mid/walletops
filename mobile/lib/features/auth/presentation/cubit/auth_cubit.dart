import 'package:dio/dio.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/auth_repository.dart';
import 'auth_state.dart';

class AuthCubit extends Cubit<AuthState> {
  AuthCubit(this._repo) : super(const AuthState());

  final AuthRepository _repo;

  Future<void> bootstrap() async {
    emit(state.copyWith(busy: true, clearError: true));
    final user = await _repo.restore();
    if (user == null) {
      emit(const AuthState(status: AuthStatus.unauthenticated));
      return;
    }
    emit(AuthState(status: AuthStatus.authenticated, user: user));
  }

  Future<void> register({
    required String email,
    required String password,
  }) async {
    emit(state.copyWith(busy: true, clearError: true));
    try {
      final user = await _repo.register(email: email, password: password);
      emit(AuthState(status: AuthStatus.authenticated, user: user));
    } catch (e) {
      emit(
        state.copyWith(
          busy: false,
          status: AuthStatus.unauthenticated,
          errorMessage: _message(e),
        ),
      );
    }
  }

  Future<void> login({
    required String email,
    required String password,
  }) async {
    emit(state.copyWith(busy: true, clearError: true));
    try {
      final user = await _repo.login(email: email, password: password);
      emit(AuthState(status: AuthStatus.authenticated, user: user));
    } catch (e) {
      emit(
        state.copyWith(
          busy: false,
          status: AuthStatus.unauthenticated,
          errorMessage: _message(e),
        ),
      );
    }
  }

  Future<void> logout() async {
    await _repo.logout();
    emit(const AuthState(status: AuthStatus.unauthenticated));
  }

  void markLoggedOut() {
    if (state.status != AuthStatus.unauthenticated) {
      emit(const AuthState(status: AuthStatus.unauthenticated));
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

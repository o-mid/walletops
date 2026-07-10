import 'package:equatable/equatable.dart';

import '../../data/auth_models.dart';

enum AuthStatus { unknown, authenticated, unauthenticated }

class AuthState extends Equatable {
  const AuthState({
    this.status = AuthStatus.unknown,
    this.user,
    this.errorMessage,
    this.busy = false,
  });

  final AuthStatus status;
  final UserProfile? user;
  final String? errorMessage;
  final bool busy;

  AuthState copyWith({
    AuthStatus? status,
    UserProfile? user,
    String? errorMessage,
    bool? busy,
    bool clearUser = false,
    bool clearError = false,
  }) {
    return AuthState(
      status: status ?? this.status,
      user: clearUser ? null : (user ?? this.user),
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      busy: busy ?? this.busy,
    );
  }

  @override
  List<Object?> get props => [status, user, errorMessage, busy];
}

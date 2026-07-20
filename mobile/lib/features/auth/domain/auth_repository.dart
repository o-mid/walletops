import '../data/auth_models.dart';

abstract class AuthRepository {
  Future<bool> hasSession();

  Future<UserProfile> register({
    required String email,
    required String password,
  });

  Future<UserProfile> login({
    required String email,
    required String password,
  });

  Future<UserProfile?> restore();

  Future<void> logout();
}

import '../../../core/error/error_mapper.dart';
import '../../../core/storage/token_storage.dart';
import '../domain/auth_repository.dart';
import 'auth_api.dart';
import 'auth_models.dart';

class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl({
    required AuthApi api,
    required TokenStorage storage,
  })  : _api = api,
        _storage = storage;

  final AuthApi _api;
  final TokenStorage _storage;

  @override
  Future<bool> hasSession() async {
    final access = await _storage.readAccessToken();
    return access != null && access.isNotEmpty;
  }

  @override
  Future<UserProfile> register({
    required String email,
    required String password,
  }) {
    return guardApi(() async {
      final tokens = await _api.register(email: email, password: password);
      await _storage.saveTokens(
        accessToken: tokens.accessToken,
        refreshToken: tokens.refreshToken,
      );
      return _api.me();
    });
  }

  @override
  Future<UserProfile> login({
    required String email,
    required String password,
  }) {
    return guardApi(() async {
      final tokens = await _api.login(email: email, password: password);
      await _storage.saveTokens(
        accessToken: tokens.accessToken,
        refreshToken: tokens.refreshToken,
      );
      return _api.me();
    });
  }

  @override
  Future<UserProfile?> restore() async {
    if (!await hasSession()) {
      return null;
    }
    try {
      return await guardApi(_api.me);
    } catch (_) {
      await _storage.clear();
      return null;
    }
  }

  @override
  Future<void> logout() => _storage.clear();
}

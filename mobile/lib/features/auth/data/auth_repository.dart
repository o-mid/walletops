import '../../../core/storage/token_storage.dart';
import 'auth_api.dart';
import 'auth_models.dart';

class AuthRepository {
  AuthRepository({
    required AuthApi api,
    required TokenStorage storage,
  })  : _api = api,
        _storage = storage;

  final AuthApi _api;
  final TokenStorage _storage;

  Future<bool> hasSession() async {
    final access = await _storage.readAccessToken();
    return access != null && access.isNotEmpty;
  }

  Future<UserProfile> register({
    required String email,
    required String password,
  }) async {
    final tokens = await _api.register(email: email, password: password);
    await _storage.saveTokens(
      accessToken: tokens.accessToken,
      refreshToken: tokens.refreshToken,
    );
    return _api.me();
  }

  Future<UserProfile> login({
    required String email,
    required String password,
  }) async {
    final tokens = await _api.login(email: email, password: password);
    await _storage.saveTokens(
      accessToken: tokens.accessToken,
      refreshToken: tokens.refreshToken,
    );
    return _api.me();
  }

  Future<UserProfile?> restore() async {
    if (!await hasSession()) {
      return null;
    }
    try {
      return await _api.me();
    } catch (_) {
      await _storage.clear();
      return null;
    }
  }

  Future<void> logout() => _storage.clear();
}

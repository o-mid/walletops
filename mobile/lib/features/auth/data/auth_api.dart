import 'package:dio/dio.dart';

import 'auth_models.dart';

class AuthApi {
  AuthApi(this._dio);

  final Dio _dio;

  Future<TokenPair> register({
    required String email,
    required String password,
  }) async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/v1/auth/register',
      data: {'email': email, 'password': password},
    );
    return TokenPair.fromJson(res.data!);
  }

  Future<TokenPair> login({
    required String email,
    required String password,
  }) async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/v1/auth/login',
      data: {'email': email, 'password': password},
    );
    return TokenPair.fromJson(res.data!);
  }

  Future<TokenPair> refresh(String refreshToken) async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/v1/auth/refresh',
      data: {'refresh_token': refreshToken},
      options: Options(extra: {'skipAuth': true}),
    );
    return TokenPair.fromJson(res.data!);
  }

  Future<UserProfile> me() async {
    final res = await _dio.get<Map<String, dynamic>>('/v1/me');
    return UserProfile.fromJson(res.data!);
  }
}

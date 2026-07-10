import 'dart:async';

import 'package:dio/dio.dart';

import '../../features/auth/data/auth_api.dart';
import '../storage/token_storage.dart';

class AuthInterceptor extends Interceptor {
  AuthInterceptor({
    required Dio dio,
    required TokenStorage storage,
    required AuthApi authApi,
    this.onSessionExpired,
  })  : _dio = dio,
        _storage = storage,
        _authApi = authApi;

  final Dio _dio;
  final TokenStorage _storage;
  final AuthApi _authApi;
  final void Function()? onSessionExpired;

  bool _refreshing = false;
  Completer<void>? _refreshGate;

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    if (options.extra['skipAuth'] == true) {
      handler.next(options);
      return;
    }
    final token = await _storage.readAccessToken();
    if (token != null && token.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final status = err.response?.statusCode;
    final req = err.requestOptions;
    final alreadyRetried = req.extra['retried'] == true;
    final skipAuth = req.extra['skipAuth'] == true;

    if (status != 401 || alreadyRetried || skipAuth) {
      handler.next(err);
      return;
    }

    try {
      await _refreshOnce();
      final access = await _storage.readAccessToken();
      if (access == null || access.isEmpty) {
        onSessionExpired?.call();
        handler.next(err);
        return;
      }
      final opts = req.copyWith(
        headers: Map<String, dynamic>.from(req.headers)
          ..['Authorization'] = 'Bearer $access',
        extra: Map<String, dynamic>.from(req.extra)..['retried'] = true,
      );
      final response = await _dio.fetch<dynamic>(opts);
      handler.resolve(response);
    } catch (_) {
      await _storage.clear();
      onSessionExpired?.call();
      handler.next(err);
    }
  }

  Future<void> _refreshOnce() async {
    if (_refreshing) {
      await _refreshGate?.future;
      return;
    }
    _refreshing = true;
    _refreshGate = Completer<void>();
    try {
      final refresh = await _storage.readRefreshToken();
      if (refresh == null || refresh.isEmpty) {
        throw StateError('missing refresh token');
      }
      final tokens = await _authApi.refresh(refresh);
      await _storage.saveTokens(
        accessToken: tokens.accessToken,
        refreshToken: tokens.refreshToken,
      );
      _refreshGate?.complete();
    } catch (e) {
      _refreshGate?.completeError(e);
      rethrow;
    } finally {
      _refreshing = false;
      _refreshGate = null;
    }
  }
}

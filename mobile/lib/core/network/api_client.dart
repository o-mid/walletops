import 'package:dio/dio.dart';

import '../../features/auth/data/auth_api.dart';
import '../constants.dart';
import '../storage/token_storage.dart';
import 'auth_interceptor.dart';

class ApiClient {
  ApiClient({
    required TokenStorage storage,
    required void Function() onSessionExpired,
    String? baseUrl,
  }) {
    dio = Dio(
      BaseOptions(
        baseUrl: baseUrl ?? kApiBase,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 20),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );
    authApi = AuthApi(dio);
    dio.interceptors.add(
      AuthInterceptor(
        dio: dio,
        storage: storage,
        authApi: authApi,
        onSessionExpired: onSessionExpired,
      ),
    );
  }

  late final Dio dio;
  late final AuthApi authApi;
}

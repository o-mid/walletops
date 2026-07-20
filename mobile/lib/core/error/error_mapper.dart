import 'package:dio/dio.dart';

import 'app_exception.dart';

AppException mapError(Object error) {
  if (error is AppException) {
    return error;
  }
  if (error is DioException) {
    return mapDioError(error);
  }
  return const AppException('Something went wrong');
}

AppException mapDioError(DioException error) {
  final data = error.response?.data;
  if (data is Map) {
    final nested = data['error'];
    if (nested is Map) {
      final message = nested['message'];
      final code = nested['code'];
      if (message is String && message.isNotEmpty) {
        return AppException(
          message,
          code: code is String ? code : null,
          statusCode: error.response?.statusCode,
        );
      }
    }
  }

  return switch (error.type) {
    DioExceptionType.connectionTimeout ||
    DioExceptionType.sendTimeout ||
    DioExceptionType.receiveTimeout =>
      const AppException('Request timed out'),
    DioExceptionType.connectionError =>
      const AppException('Cannot reach API'),
    _ => AppException(
        'Request failed',
        statusCode: error.response?.statusCode,
      ),
  };
}

Future<T> guardApi<T>(Future<T> Function() run) async {
  try {
    return await run();
  } on DioException catch (e) {
    throw mapDioError(e);
  }
}

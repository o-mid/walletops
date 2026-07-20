import 'package:dio/dio.dart';

import '../../../core/network/request_options.dart';
import 'health_models.dart';

class HealthApi {
  HealthApi(this._dio);

  final Dio _dio;

  Future<OpsHealth> fetch() async {
    final res = await _dio.get<Map<String, dynamic>>(
      '/v1/health',
      options: skipAuthOptions(),
    );
    return OpsHealth.fromJson(res.data ?? const {});
  }
}

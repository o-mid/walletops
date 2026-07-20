import 'package:dio/dio.dart';

import 'health_models.dart';

class HealthApi {
  HealthApi(this._dio);

  final Dio _dio;

  Future<OpsHealth> fetch() async {
    final res = await _dio.get<Map<String, dynamic>>('/v1/health');
    return OpsHealth.fromJson(res.data ?? const {});
  }
}

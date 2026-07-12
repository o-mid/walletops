import 'package:dio/dio.dart';

import 'rule_models.dart';

class RulesApi {
  RulesApi(this._dio);

  final Dio _dio;

  Future<List<AlertRule>> list() async {
    final res = await _dio.get<Map<String, dynamic>>('/v1/alert-rules');
    final items = res.data?['items'] as List<dynamic>? ?? [];
    return items
        .map((e) => AlertRule.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<AlertRule> create({
    required String name,
    required String eventType,
    double? threshold,
    bool enabled = true,
  }) async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/v1/alert-rules',
      data: {
        'name': name,
        'event_type': eventType,
        'threshold': threshold,
        'enabled': enabled,
      },
    );
    return AlertRule.fromJson(res.data!);
  }

  Future<AlertRule> update({
    required String id,
    String? name,
    String? eventType,
    double? threshold,
    bool clearThreshold = false,
    bool? enabled,
  }) async {
    final body = <String, dynamic>{
      'name': ?name,
      'event_type': ?eventType,
      'enabled': ?enabled,
    };
    if (clearThreshold) {
      body['threshold'] = null;
    } else if (threshold != null) {
      body['threshold'] = threshold;
    }
    final res = await _dio.patch<Map<String, dynamic>>(
      '/v1/alert-rules/$id',
      data: body,
    );
    return AlertRule.fromJson(res.data!);
  }

  Future<void> delete(String id) async {
    await _dio.delete<void>('/v1/alert-rules/$id');
  }
}

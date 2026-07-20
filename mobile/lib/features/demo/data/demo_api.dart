import 'package:dio/dio.dart';

import '../../events/data/event_models.dart';
import 'demo_models.dart';

class DemoApi {
  DemoApi(this._dio);

  final Dio _dio;

  Future<DemoSimulateResult> simulate({
    int count = 1,
    bool ensureDemoRule = true,
  }) async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/v1/demo/simulate',
      data: {
        'count': count,
        'ensure_demo_rule': ensureDemoRule,
      },
    );
    final data = res.data ?? {};
    final raw = data['events'] as List? ?? const [];
    return DemoSimulateResult(
      events: raw
          .map((e) => OpsEvent.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
      demoRuleId: data['demo_rule_id'] as String?,
      demoRuleCreated: data['demo_rule_created'] as bool? ?? false,
      hint: data['hint'] as String? ?? '',
    );
  }
}

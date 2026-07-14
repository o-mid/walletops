import 'package:dio/dio.dart';

import 'summary_models.dart';

class AiApi {
  AiApi(this._dio);

  final Dio _dio;

  Future<EventSummary> summarize(List<String> eventIds) async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/v1/ai/summarize',
      data: {'event_ids': eventIds},
    );
    return EventSummary.fromJson(res.data!);
  }
}

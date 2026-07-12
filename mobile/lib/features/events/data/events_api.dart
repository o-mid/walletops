import 'package:dio/dio.dart';

import 'event_models.dart';

class EventsApi {
  EventsApi(this._dio);

  final Dio _dio;

  Future<List<OpsEvent>> list({String? status}) async {
    final res = await _dio.get<Map<String, dynamic>>(
      '/v1/events',
      queryParameters: {
        if (status != null && status.isNotEmpty) 'status': status,
      },
    );
    final items = res.data?['items'] as List<dynamic>? ?? [];
    return items
        .map((e) => OpsEvent.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<OpsEvent> getById(String id) async {
    final res = await _dio.get<Map<String, dynamic>>('/v1/events/$id');
    return OpsEvent.fromJson(res.data!);
  }
}

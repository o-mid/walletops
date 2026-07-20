import 'dart:convert';

import 'package:equatable/equatable.dart';

class OpsEvent extends Equatable {
  const OpsEvent({
    required this.id,
    required this.userId,
    required this.idempotencyKey,
    required this.type,
    required this.payload,
    required this.status,
    required this.attemptCount,
    this.lastError,
    this.matchedRuleId,
    required this.receivedAt,
    this.processedAt,
  });

  factory OpsEvent.fromJson(Map<String, dynamic> json) {
    return OpsEvent(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      idempotencyKey: json['idempotency_key'] as String,
      type: json['type'] as String,
      payload: Map<String, dynamic>.from(json['payload'] as Map? ?? {}),
      status: json['status'] as String,
      attemptCount: json['attempt_count'] as int? ?? 0,
      lastError: json['last_error'] as String?,
      matchedRuleId: json['matched_rule_id'] as String?,
      receivedAt: DateTime.parse(json['received_at'] as String),
      processedAt: json['processed_at'] == null
          ? null
          : DateTime.parse(json['processed_at'] as String),
    );
  }

  final String id;
  final String userId;
  final String idempotencyKey;
  final String type;
  final Map<String, dynamic> payload;
  final String status;
  final int attemptCount;
  final String? lastError;
  final String? matchedRuleId;
  final DateTime receivedAt;
  final DateTime? processedAt;

  String get prettyPayload =>
      const JsonEncoder.withIndent('  ').convert(payload);

  String? get asset => payload['asset']?.toString();

  double? get amount {
    final raw = payload['amount'];
    if (raw is num) {
      return raw.toDouble();
    }
    return null;
  }

  String? get addressLabel => payload['address_label']?.toString();

  String get listSubtitle {
    final parts = <String>[];
    if (amount != null && asset != null) {
      parts.add('$amount $asset');
    } else if (asset != null) {
      parts.add(asset!);
    }
    if (addressLabel != null) {
      parts.add(addressLabel!);
    }
    parts.add(pipelineHint);
    return parts.join(' · ');
  }

  String get pipelineHint => switch (status) {
        'pending' => 'queued for worker',
        'processing' => 'claimed by worker',
        'processed' => matchedRuleId != null
            ? 'done · rule matched'
            : 'done · no rule match',
        'failed' => 'failed · attempt $attemptCount',
        _ => status,
      };

  @override
  List<Object?> get props => [id, status, type, receivedAt];
}

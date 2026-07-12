import 'package:equatable/equatable.dart';

class AlertRule extends Equatable {
  const AlertRule({
    required this.id,
    required this.userId,
    required this.name,
    required this.eventType,
    this.threshold,
    required this.enabled,
    required this.createdAt,
    required this.updatedAt,
  });

  factory AlertRule.fromJson(Map<String, dynamic> json) {
    return AlertRule(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      name: json['name'] as String,
      eventType: json['event_type'] as String,
      threshold: (json['threshold'] as num?)?.toDouble(),
      enabled: json['enabled'] as bool? ?? true,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  final String id;
  final String userId;
  final String name;
  final String eventType;
  final double? threshold;
  final bool enabled;
  final DateTime createdAt;
  final DateTime updatedAt;

  @override
  List<Object?> get props => [id, name, eventType, threshold, enabled];
}

const kEventTypes = <String>[
  'tx_simulated',
  'balance_drop',
  'partner_kyc',
  'swap_quote',
  'custom',
];

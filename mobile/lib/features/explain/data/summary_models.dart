import 'package:equatable/equatable.dart';

class EventSummary extends Equatable {
  const EventSummary({
    required this.title,
    required this.summaryBullets,
    required this.riskLevel,
    required this.followUps,
    required this.eventIds,
  });

  factory EventSummary.fromJson(Map<String, dynamic> json) {
    return EventSummary(
      title: json['title'] as String,
      summaryBullets: (json['summary_bullets'] as List<dynamic>)
          .map((e) => e as String)
          .toList(),
      riskLevel: json['risk_level'] as String,
      followUps: (json['follow_ups'] as List<dynamic>)
          .map((e) => e as String)
          .toList(),
      eventIds: (json['event_ids'] as List<dynamic>)
          .map((e) => e as String)
          .toList(),
    );
  }

  final String title;
  final List<String> summaryBullets;
  final String riskLevel;
  final List<String> followUps;
  final List<String> eventIds;

  @override
  List<Object?> get props =>
      [title, summaryBullets, riskLevel, followUps, eventIds];
}

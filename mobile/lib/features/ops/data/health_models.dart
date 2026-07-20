class OpsHealth {
  const OpsHealth({
    required this.status,
    this.worker,
    this.queue,
  });

  factory OpsHealth.fromJson(Map<String, dynamic> json) {
    return OpsHealth(
      status: json['status'] as String? ?? 'unknown',
      worker: json['worker'] is Map<String, dynamic>
          ? WorkerHealth.fromJson(json['worker'] as Map<String, dynamic>)
          : null,
      queue: json['queue'] is Map<String, dynamic>
          ? QueueHealth.fromJson(json['queue'] as Map<String, dynamic>)
          : null,
    );
  }

  final String status;
  final WorkerHealth? worker;
  final QueueHealth? queue;

  bool get ok => status == 'ok';
}

class WorkerHealth {
  const WorkerHealth({
    this.lastTick,
    required this.processedTotal,
    required this.errorTotal,
  });

  factory WorkerHealth.fromJson(Map<String, dynamic> json) {
    return WorkerHealth(
      lastTick: json['last_tick'] == null
          ? null
          : DateTime.tryParse(json['last_tick'] as String)?.toLocal(),
      processedTotal: (json['processed_total'] as num?)?.toInt() ?? 0,
      errorTotal: (json['error_total'] as num?)?.toInt() ?? 0,
    );
  }

  final DateTime? lastTick;
  final int processedTotal;
  final int errorTotal;
}

class QueueHealth {
  const QueueHealth({
    required this.byStatus,
    this.oldestPendingSeconds,
  });

  factory QueueHealth.fromJson(Map<String, dynamic> json) {
    final raw = json['by_status'];
    final map = <String, int>{};
    if (raw is Map) {
      raw.forEach((key, value) {
        map['$key'] = (value as num?)?.toInt() ?? 0;
      });
    }
    return QueueHealth(
      byStatus: map,
      oldestPendingSeconds: (json['oldest_pending_seconds'] as num?)?.toDouble(),
    );
  }

  final Map<String, int> byStatus;
  final double? oldestPendingSeconds;

  int count(String status) => byStatus[status] ?? 0;
}

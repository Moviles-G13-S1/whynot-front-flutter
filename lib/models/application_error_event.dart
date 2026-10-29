/// Sanitized technical telemetry. Never includes messages, stacks or form data.
class ApplicationErrorEvent {
  const ApplicationErrorEvent({
    required this.id,
    required this.occurredAt,
    required this.platform,
    required this.feature,
    required this.operation,
    required this.code,
    required this.source,
    this.ownerId,
  });

  final String id;
  final DateTime occurredAt;
  final String platform, feature, operation, code, source;
  final String? ownerId;

  Map<String, Object?> toLocalMap() => {
    'eventId': id,
    'occurredAt': occurredAt.toUtc().toIso8601String(),
    'platform': platform,
    'feature': feature,
    'operation': operation,
    'code': code,
    'source': source,
    'ownerId': ownerId,
  };

  factory ApplicationErrorEvent.fromLocalMap(Map<String, dynamic> data) =>
      ApplicationErrorEvent(
        id: data['eventId'] as String,
        occurredAt: DateTime.parse(data['occurredAt'] as String).toUtc(),
        platform: data['platform'] as String,
        feature: data['feature'] as String,
        operation: data['operation'] as String,
        code: data['code'] as String,
        source: data['source'] as String,
        ownerId: data['ownerId'] as String?,
      );
}

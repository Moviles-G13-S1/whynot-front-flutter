class RecommendedProductSaves {
  const RecommendedProductSaves({required this.total});

  factory RecommendedProductSaves.fromEvents(
    Iterable<Map<String, dynamic>> events,
  ) => RecommendedProductSaves(
    total: events.where((event) {
      final savedProductId = event['savedProductId'];
      return event['eventType'] == 'recommendation_shown' &&
          event['savedAt'] != null &&
          savedProductId is String &&
          savedProductId.isNotEmpty;
    }).length,
  );

  final int total;
}

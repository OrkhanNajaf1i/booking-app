/// Bildiriş — həm in-app siyahı, həm də WebSocket-dən gələn canlı hadisə
/// eyni formadadır.
class AppNotification {
  const AppNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.createdAt,
    required this.isRead,
    this.bookingId,
    this.businessId,
    this.payload = const {},
  });

  final String id;
  final String type;
  final String title;
  final String body;
  final DateTime createdAt;
  final bool isRead;
  final String? bookingId;
  final String? businessId;
  final Map<String, dynamic> payload;

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    return AppNotification(
      id: json['id'] as String? ?? '',
      type: json['type'] as String? ?? '',
      title: json['title'] as String? ?? '',
      body: json['body'] as String? ?? '',
      createdAt: DateTime.parse(
        json['created_at'] as String? ?? DateTime.now().toIso8601String(),
      ).toLocal(),
      isRead: json['is_read'] as bool? ?? false,
      bookingId: json['booking_id'] as String?,
      businessId: json['business_id'] as String?,
      payload: (json['payload'] as Map<String, dynamic>?) ?? const {},
    );
  }

  /// WebSocket zərfindən qurur.
  ///
  /// Canlı hadisədə `id` sahəsi yoxdur — backend onu payload-a
  /// `notification_id` kimi qoyur.
  factory AppNotification.fromEnvelope(Map<String, dynamic> json) {
    final payload = (json['payload'] as Map<String, dynamic>?) ?? const {};

    return AppNotification(
      id: (payload['notification_id'] as String?) ??
          DateTime.now().microsecondsSinceEpoch.toString(),
      type: json['type'] as String? ?? '',
      title: json['title'] as String? ?? '',
      body: json['body'] as String? ?? '',
      createdAt: DateTime.parse(
        json['created_at'] as String? ?? DateTime.now().toIso8601String(),
      ).toLocal(),
      isRead: false,
      bookingId: json['booking_id'] as String?,
      businessId: json['business_id'] as String?,
      payload: payload,
    );
  }
}

/// Hadisə növünə görə ikon.
String notificationIcon(String type) {
  switch (type) {
    case 'booking.created':
      return '📩';
    case 'booking.confirmed':
      return '✅';
    case 'booking.reschedule_proposed':
      return '🔄';
    case 'booking.reschedule_accepted':
      return '👍';
    case 'booking.reschedule_declined':
      return '↩️';
    case 'booking.cancelled':
      return '❌';
    case 'booking.completed':
      return '🏁';
    case 'booking.no_show':
      return '🚫';
    case 'booking.reminder':
      return '⏰';
    default:
      return '🔔';
  }
}

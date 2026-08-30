enum BookingStatus {
  pending,
  confirmed,
  rescheduleProposed,
  cancelled,
  completed,
  noShow,
  unknown,
}

BookingStatus parseBookingStatus(String? raw) {
  switch (raw) {
    case 'pending':
      return BookingStatus.pending;
    case 'confirmed':
      return BookingStatus.confirmed;
    case 'reschedule_proposed':
      return BookingStatus.rescheduleProposed;
    case 'cancelled':
      return BookingStatus.cancelled;
    case 'completed':
      return BookingStatus.completed;
    case 'no_show':
      return BookingStatus.noShow;
    default:
      return BookingStatus.unknown;
  }
}

String bookingStatusLabel(BookingStatus status) {
  switch (status) {
    case BookingStatus.pending:
      return 'Təsdiq gözləyir';
    case BookingStatus.confirmed:
      return 'Təsdiqlənib';
    case BookingStatus.rescheduleProposed:
      return 'Yeni vaxt təklif olunub';
    case BookingStatus.cancelled:
      return 'Ləğv edilib';
    case BookingStatus.completed:
      return 'Tamamlanıb';
    case BookingStatus.noShow:
      return 'Gəlmədi';
    case BookingStatus.unknown:
      return 'Naməlum';
  }
}

/// Enum -> backend-in isletdiyi ad.
/// `.name` istifade etsek `noShow` cixir, backend ise `no_show` gozleyir.
String bookingStatusRaw(BookingStatus status) {
  switch (status) {
    case BookingStatus.pending:
      return 'pending';
    case BookingStatus.confirmed:
      return 'confirmed';
    case BookingStatus.rescheduleProposed:
      return 'reschedule_proposed';
    case BookingStatus.cancelled:
      return 'cancelled';
    case BookingStatus.completed:
      return 'completed';
    case BookingStatus.noShow:
      return 'no_show';
    case BookingStatus.unknown:
      return 'unknown';
  }
}

class Booking {
  const Booking({
    required this.id,
    required this.businessId,
    required this.customerId,
    required this.staffId,
    required this.startTime,
    required this.endTime,
    required this.durationMins,
    required this.status,
    required this.notes,
    this.serviceId,
    this.proposedStartTime,
    this.proposedEndTime,
    this.proposalNote,
    this.cancelReason,
  });

  final String id;
  final String businessId;
  final String customerId;
  final String staffId;
  final String? serviceId;

  final DateTime startTime;
  final DateTime endTime;
  final int durationMins;
  final BookingStatus status;
  final String notes;

  /// Provider alternativ vaxt təklif edəndə dolur.
  final DateTime? proposedStartTime;
  final DateTime? proposedEndTime;
  final String? proposalNote;

  final String? cancelReason;

  /// Müştəridən cavab gözlənilən təklif varmı?
  bool get hasPendingProposal =>
      status == BookingStatus.rescheduleProposed && proposedStartTime != null;

  /// Vaxtı hələ tutan statuslar.
  bool get isActive =>
      status == BookingStatus.pending ||
      status == BookingStatus.confirmed ||
      status == BookingStatus.rescheduleProposed;

  factory Booking.fromJson(Map<String, dynamic> json) {
    DateTime? parseOptional(String key) {
      final raw = json[key] as String?;
      return raw == null ? null : DateTime.parse(raw).toLocal();
    }

    return Booking(
      id: json['id'] as String,
      businessId: json['business_id'] as String? ?? '',
      customerId: json['customer_id'] as String? ?? '',
      staffId: json['staff_id'] as String? ?? '',
      serviceId: json['service_id'] as String?,
      startTime: DateTime.parse(json['start_time'] as String).toLocal(),
      endTime: DateTime.parse(json['end_time'] as String).toLocal(),
      durationMins: (json['duration_mins'] as num?)?.toInt() ?? 0,
      status: parseBookingStatus(json['status'] as String?),
      notes: json['notes'] as String? ?? '',
      proposedStartTime: parseOptional('proposed_start_time'),
      proposedEndTime: parseOptional('proposed_end_time'),
      proposalNote: json['proposal_note'] as String?,
      cancelReason: json['cancel_reason'] as String?,
    );
  }
}

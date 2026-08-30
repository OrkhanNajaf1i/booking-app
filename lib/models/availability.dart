/// Boş vaxtlar backend-də iş qrafiki, nahar fasiləsi və slot addımından
/// runtime-da hesablanır. Burada yalnız gələn nəticəni oxuyuruq.
library;

enum SlotState { available, booked, blocked, past, tooSoon, tooFar, unknown }

SlotState _parseState(String? raw) {
  switch (raw) {
    case 'available':
      return SlotState.available;
    case 'booked':
      return SlotState.booked;
    case 'blocked':
      return SlotState.blocked;
    case 'past':
      return SlotState.past;
    case 'too_soon':
      return SlotState.tooSoon;
    case 'too_far':
      return SlotState.tooFar;
    default:
      return SlotState.unknown;
  }
}

/// Vaxtın niyə seçilə bilmədiyini izah edir (tooltip/snackbar üçün).
String slotStateLabel(SlotState state) {
  switch (state) {
    case SlotState.available:
      return 'Boşdur';
    case SlotState.booked:
      return 'Bron olunub';
    case SlotState.blocked:
      return 'Bağlıdır';
    case SlotState.past:
      return 'Vaxtı keçib';
    case SlotState.tooSoon:
      return 'Çox yaxın vaxtdır';
    case SlotState.tooFar:
      return 'Çox irəli tarixdir';
    case SlotState.unknown:
      return 'Əlçatan deyil';
  }
}

class TimeSlot {
  const TimeSlot({
    required this.start,
    required this.end,
    required this.durationMins,
    required this.state,
    required this.available,
  });

  final DateTime start;
  final DateTime end;
  final int durationMins;
  final SlotState state;
  final bool available;

  factory TimeSlot.fromJson(Map<String, dynamic> json) {
    return TimeSlot(
      // toLocal(): backend UTC göndərir, istifadəçi öz saatını görməlidir.
      start: DateTime.parse(json['start'] as String).toLocal(),
      end: DateTime.parse(json['end'] as String).toLocal(),
      durationMins: (json['duration_mins'] as num?)?.toInt() ?? 0,
      state: _parseState(json['state'] as String?),
      available: json['available'] as bool? ?? false,
    );
  }

  /// Backend-ə göndəriləcək dəyər — orijinal ISO forması.
  String get startIso => start.toUtc().toIso8601String();
}

class BreakInfo {
  const BreakInfo({required this.start, required this.end});

  final String start; // "13:00"
  final String end; // "14:00"

  factory BreakInfo.fromJson(Map<String, dynamic> json) => BreakInfo(
        start: json['start'] as String? ?? '',
        end: json['end'] as String? ?? '',
      );
}

class DayAvailability {
  const DayAvailability({
    required this.date,
    required this.dayOfWeek,
    required this.isWorkday,
    required this.slots,
    this.opensAt,
    this.closesAt,
    this.breakInfo,
  });

  final String date;
  final int dayOfWeek;
  final bool isWorkday;
  final List<TimeSlot> slots;
  final String? opensAt;
  final String? closesAt;
  final BreakInfo? breakInfo;

  /// Yalnız seçilə bilən vaxtlar.
  List<TimeSlot> get availableSlots =>
      slots.where((slot) => slot.available).toList();

  factory DayAvailability.fromJson(Map<String, dynamic> json) {
    final rawSlots = (json['slots'] as List<dynamic>?) ?? const [];
    final rawBreak = json['break'] as Map<String, dynamic>?;

    return DayAvailability(
      date: json['date'] as String? ?? '',
      dayOfWeek: (json['day_of_week'] as num?)?.toInt() ?? 0,
      isWorkday: json['is_workday'] as bool? ?? false,
      opensAt: json['opens_at'] as String?,
      closesAt: json['closes_at'] as String?,
      breakInfo: rawBreak == null ? null : BreakInfo.fromJson(rawBreak),
      slots: rawSlots
          .map((item) => TimeSlot.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
  }
}

class AvailabilityResult {
  const AvailabilityResult({
    required this.staffId,
    required this.timezone,
    required this.durationMins,
    required this.slotStepMins,
    required this.days,
  });

  final String staffId;
  final String timezone;
  final int durationMins;
  final int slotStepMins;
  final List<DayAvailability> days;

  factory AvailabilityResult.fromJson(Map<String, dynamic> json) {
    final rawDays = (json['days'] as List<dynamic>?) ?? const [];

    return AvailabilityResult(
      staffId: json['staff_id'] as String? ?? '',
      timezone: json['timezone'] as String? ?? 'UTC',
      durationMins: (json['duration_mins'] as num?)?.toInt() ?? 0,
      slotStepMins: (json['slot_step_mins'] as num?)?.toInt() ?? 0,
      days: rawDays
          .map((item) => DayAvailability.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
  }
}

// ─── Provider tərəfi: iş saatları və ayarlar ─────────────────

class WorkingHours {
  const WorkingHours({
    required this.dayOfWeek,
    required this.startTime,
    required this.endTime,
    required this.breakEnabled,
    required this.isActive,
    this.id,
    this.breakStart,
    this.breakEnd,
  });

  final String? id;
  final int dayOfWeek;
  final String startTime;
  final String endTime;
  final bool breakEnabled;
  final String? breakStart;
  final String? breakEnd;
  final bool isActive;

  factory WorkingHours.fromJson(Map<String, dynamic> json) => WorkingHours(
        id: json['id'] as String?,
        dayOfWeek: (json['day_of_week'] as num?)?.toInt() ?? 0,
        startTime: json['start_time'] as String? ?? '09:00',
        endTime: json['end_time'] as String? ?? '18:00',
        breakEnabled: json['break_enabled'] as bool? ?? false,
        breakStart: json['break_start'] as String?,
        breakEnd: json['break_end'] as String?,
        isActive: json['is_active'] as bool? ?? false,
      );

  Map<String, dynamic> toJson(String staffId) => {
        'staff_id': staffId,
        'day_of_week': dayOfWeek,
        'start_time': startTime,
        'end_time': endTime,
        'break_enabled': breakEnabled,
        'break_start': breakStart,
        'break_end': breakEnd,
        'is_active': isActive,
      };

  WorkingHours copyWith({
    String? startTime,
    String? endTime,
    bool? breakEnabled,
    String? breakStart,
    String? breakEnd,
    bool? isActive,
  }) {
    return WorkingHours(
      id: id,
      dayOfWeek: dayOfWeek,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      breakEnabled: breakEnabled ?? this.breakEnabled,
      breakStart: breakStart ?? this.breakStart,
      breakEnd: breakEnd ?? this.breakEnd,
      isActive: isActive ?? this.isActive,
    );
  }
}

class ScheduleSettings {
  const ScheduleSettings({
    required this.slotStepMins,
    required this.defaultDurationMins,
    required this.bufferBeforeMins,
    required this.bufferAfterMins,
    required this.minNoticeMins,
    required this.maxAdvanceDays,
    required this.autoConfirm,
    required this.allowRescheduleProposal,
    this.timezone = 'Asia/Baku',
  });

  final int slotStepMins;
  final int defaultDurationMins;
  final int bufferBeforeMins;
  final int bufferAfterMins;
  final int minNoticeMins;
  final int maxAdvanceDays;
  final bool autoConfirm;
  final bool allowRescheduleProposal;
  final String timezone;

  factory ScheduleSettings.fromJson(Map<String, dynamic> json) =>
      ScheduleSettings(
        slotStepMins: (json['slot_step_mins'] as num?)?.toInt() ?? 30,
        defaultDurationMins:
            (json['default_duration_mins'] as num?)?.toInt() ?? 30,
        bufferBeforeMins: (json['buffer_before_mins'] as num?)?.toInt() ?? 0,
        bufferAfterMins: (json['buffer_after_mins'] as num?)?.toInt() ?? 0,
        minNoticeMins: (json['min_notice_mins'] as num?)?.toInt() ?? 60,
        maxAdvanceDays: (json['max_advance_days'] as num?)?.toInt() ?? 30,
        autoConfirm: json['auto_confirm'] as bool? ?? false,
        allowRescheduleProposal:
            json['allow_reschedule_proposal'] as bool? ?? true,
        timezone: json['timezone'] as String? ?? 'Asia/Baku',
      );

  Map<String, dynamic> toJson({String? staffId}) => {
        if (staffId != null) 'staff_id': staffId,
        'slot_step_mins': slotStepMins,
        'default_duration_mins': defaultDurationMins,
        'buffer_before_mins': bufferBeforeMins,
        'buffer_after_mins': bufferAfterMins,
        'min_notice_mins': minNoticeMins,
        'max_advance_days': maxAdvanceDays,
        'auto_confirm': autoConfirm,
        'allow_reschedule_proposal': allowRescheduleProposal,
      };

  ScheduleSettings copyWith({
    int? slotStepMins,
    int? defaultDurationMins,
    int? bufferBeforeMins,
    int? bufferAfterMins,
    int? minNoticeMins,
    int? maxAdvanceDays,
    bool? autoConfirm,
    bool? allowRescheduleProposal,
  }) {
    return ScheduleSettings(
      slotStepMins: slotStepMins ?? this.slotStepMins,
      defaultDurationMins: defaultDurationMins ?? this.defaultDurationMins,
      bufferBeforeMins: bufferBeforeMins ?? this.bufferBeforeMins,
      bufferAfterMins: bufferAfterMins ?? this.bufferAfterMins,
      minNoticeMins: minNoticeMins ?? this.minNoticeMins,
      maxAdvanceDays: maxAdvanceDays ?? this.maxAdvanceDays,
      autoConfirm: autoConfirm ?? this.autoConfirm,
      allowRescheduleProposal:
          allowRescheduleProposal ?? this.allowRescheduleProposal,
      timezone: timezone,
    );
  }
}

const List<String> dayNamesAz = [
  'Bazar',
  'Bazar ertəsi',
  'Çərşənbə axşamı',
  'Çərşənbə',
  'Cümə axşamı',
  'Cümə',
  'Şənbə',
];

import 'package:flutter/material.dart';

import '../../core/api/api_client.dart';
import '../../models/availability.dart';
import '../../models/staff.dart';
import '../../repositories/repositories.dart';

/// Provider öz iş qaydalarını buradan qurur:
///   • həftəlik iş saatları
///   • nahar fasiləsi (söndürülə bilər)
///   • seçim addımı — 16, 30, 60 dəq
///
/// Yazılan kimi müştərinin gördüyü boş vaxtlar dəyişir; heç nə
/// yenidən generasiya olunmur.
class ScheduleScreen extends StatefulWidget {
  const ScheduleScreen({super.key});

  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen> {
  static const _availabilityRepo = AvailabilityRepository();
  static const _staffRepo = StaffRepository();

  List<StaffMember> _staff = const [];
  StaffMember? _selectedStaff;

  List<WorkingHours> _week = const [];
  ScheduleSettings? _settings;

  bool _loading = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final staff = await _staffRepo.list();
      if (staff.isEmpty) {
        if (!mounted) return;
        setState(() {
          _staff = const [];
          _loading = false;
        });
        return;
      }

      final selected = _selectedStaff ?? staff.first;
      final week = await _availabilityRepo.listWorkingHours(selected.id);
      final settings = await _availabilityRepo.getSettings(staffId: selected.id);

      if (!mounted) return;
      setState(() {
        _staff = staff;
        _selectedStaff = selected;
        _week = _mergeWeek(week);
        _settings = settings;
        _loading = false;
      });
    } on ApiException catch (exception) {
      if (!mounted) return;
      setState(() {
        _error = exception.message;
        _loading = false;
      });
    }
  }

  /// Serverdən gələn qismən həftəni 7 günlük tam formaya açır.
  List<WorkingHours> _mergeWeek(List<WorkingHours> saved) {
    final byDay = {for (final row in saved) row.dayOfWeek: row};

    return List.generate(7, (day) {
      return byDay[day] ??
          WorkingHours(
            dayOfWeek: day,
            startTime: '09:00',
            endTime: '18:00',
            breakEnabled: false,
            breakStart: '13:00',
            breakEnd: '14:00',
            // Standart iş həftəsi: B.e–Cümə.
            isActive: day >= 1 && day <= 5,
          );
    });
  }

  void _updateDay(int day, WorkingHours updated) {
    setState(() {
      _week = [
        for (final row in _week)
          if (row.dayOfWeek == day) updated else row,
      ];
    });
  }

  Future<void> _pickTime(int day, {required bool isStart, bool isBreak = false}) async {
    final row = _week.firstWhere((item) => item.dayOfWeek == day);

    final current = isBreak
        ? (isStart ? row.breakStart : row.breakEnd) ?? '13:00'
        : (isStart ? row.startTime : row.endTime);

    final parts = current.split(':');
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: int.tryParse(parts.first) ?? 9,
        minute: int.tryParse(parts.last) ?? 0,
      ),
    );
    if (picked == null) return;

    final value = '${picked.hour.toString().padLeft(2, '0')}:'
        '${picked.minute.toString().padLeft(2, '0')}';

    _updateDay(
      day,
      isBreak
          ? row.copyWith(
              breakStart: isStart ? value : null,
              breakEnd: isStart ? null : value,
            )
          : row.copyWith(
              startTime: isStart ? value : null,
              endTime: isStart ? null : value,
            ),
    );
  }

  Future<void> _save() async {
    final staff = _selectedStaff;
    final settings = _settings;
    if (staff == null || settings == null) return;

    setState(() => _saving = true);

    try {
      await _availabilityRepo.saveWeek(staff.id, _week);
      await _availabilityRepo.updateSettings(settings, staffId: staff.id);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Qrafik yadda saxlanıldı')),
      );
    } on ApiException catch (exception) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(exception.message)),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());

    if (_staff.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(
            _error ?? 'Qrafik təyin etmək üçün əvvəlcə işçi əlavə edin',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    final settings = _settings!;
    final theme = Theme.of(context);

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (_staff.length > 1) ...[
                DropdownButtonFormField<String>(
                  initialValue: _selectedStaff?.id,
                  decoration: const InputDecoration(labelText: 'İşçi'),
                  items: _staff
                      .map(
                        (member) => DropdownMenuItem(
                          value: member.id,
                          child: Text(member.displayName),
                        ),
                      )
                      .toList(),
                  onChanged: (id) {
                    if (id == null) return;
                    setState(() {
                      _selectedStaff =
                          _staff.firstWhere((member) => member.id == id);
                    });
                    _load();
                  },
                ),
                const SizedBox(height: 20),
              ],

              Text(
                'Həftəlik iş saatları',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),

              ..._week.map(
                (row) => _DayRow(
                  row: row,
                  onToggleActive: (value) =>
                      _updateDay(row.dayOfWeek, row.copyWith(isActive: value)),
                  onToggleBreak: (value) => _updateDay(
                    row.dayOfWeek,
                    row.copyWith(breakEnabled: value),
                  ),
                  onPickStart: () => _pickTime(row.dayOfWeek, isStart: true),
                  onPickEnd: () => _pickTime(row.dayOfWeek, isStart: false),
                  onPickBreakStart: () =>
                      _pickTime(row.dayOfWeek, isStart: true, isBreak: true),
                  onPickBreakEnd: () =>
                      _pickTime(row.dayOfWeek, isStart: false, isBreak: true),
                ),
              ),

              const SizedBox(height: 24),
              Text(
                'Seçim qaydaları',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Müştərinin gördüyü vaxtların necə kəsiləcəyini təyin edir.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 12),

              _NumberRow(
                label: 'Seçim addımı',
                suffix: 'dəq',
                hint: '16 qoysanız: 09:00, 09:16, 09:32 …',
                value: settings.slotStepMins,
                min: 5,
                max: 480,
                onChanged: (value) => setState(
                  () => _settings = settings.copyWith(slotStepMins: value),
                ),
              ),
              _NumberRow(
                label: 'Randevu uzunluğu',
                suffix: 'dəq',
                hint: 'Xidmət seçilməyəndə işlənir',
                value: settings.defaultDurationMins,
                min: 5,
                max: 1440,
                onChanged: (value) => setState(
                  () =>
                      _settings = settings.copyWith(defaultDurationMins: value),
                ),
              ),
              _NumberRow(
                label: 'Sonrakı bufer',
                suffix: 'dəq',
                hint: 'Randevular arasında saxlanılan boşluq',
                value: settings.bufferAfterMins,
                min: 0,
                max: 240,
                onChanged: (value) => setState(
                  () => _settings = settings.copyWith(bufferAfterMins: value),
                ),
              ),
              _NumberRow(
                label: 'Minimum xəbərdarlıq',
                suffix: 'dəq',
                hint: 'Bu qədər əvvəlcədən bron edilə bilər',
                value: settings.minNoticeMins,
                min: 0,
                max: 43200,
                onChanged: (value) => setState(
                  () => _settings = settings.copyWith(minNoticeMins: value),
                ),
              ),

              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Avtomatik təsdiq'),
                subtitle: const Text(
                  'Aktivdirsə bron təsdiq gözləmədən dərhal təsdiqlənir',
                ),
                value: settings.autoConfirm,
                onChanged: (value) => setState(
                  () => _settings = settings.copyWith(autoConfirm: value),
                ),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Alternativ vaxt təklifi'),
                subtitle: const Text(
                  'Müştəriyə başqa vaxt təklif edə bilməniz üçün',
                ),
                value: settings.allowRescheduleProposal,
                onChanged: (value) => setState(
                  () => _settings =
                      settings.copyWith(allowRescheduleProposal: value),
                ),
              ),

              const SizedBox(height: 80),
            ],
          ),
        ),

        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: FilledButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Yadda saxla'),
            ),
          ),
        ),
      ],
    );
  }
}

// ═════════════════════════════════════════════════════════════

class _DayRow extends StatelessWidget {
  const _DayRow({
    required this.row,
    required this.onToggleActive,
    required this.onToggleBreak,
    required this.onPickStart,
    required this.onPickEnd,
    required this.onPickBreakStart,
    required this.onPickBreakEnd,
  });

  final WorkingHours row;
  final ValueChanged<bool> onToggleActive;
  final ValueChanged<bool> onToggleBreak;
  final VoidCallback onPickStart;
  final VoidCallback onPickEnd;
  final VoidCallback onPickBreakStart;
  final VoidCallback onPickBreakEnd;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          children: [
            Row(
              children: [
                Switch(value: row.isActive, onChanged: onToggleActive),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    dayNamesAz[row.dayOfWeek],
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                      color: row.isActive ? null : theme.colorScheme.outline,
                    ),
                  ),
                ),
                if (row.isActive) ...[
                  _TimeButton(label: row.startTime, onTap: onPickStart),
                  const Text(' – '),
                  _TimeButton(label: row.endTime, onTap: onPickEnd),
                ],
              ],
            ),

            if (row.isActive)
              Row(
                children: [
                  const SizedBox(width: 8),
                  Icon(
                    Icons.free_breakfast_outlined,
                    size: 16,
                    color: theme.colorScheme.outline,
                  ),
                  const SizedBox(width: 6),
                  const Text('Nahar', style: TextStyle(fontSize: 13)),
                  const Spacer(),
                  if (row.breakEnabled) ...[
                    _TimeButton(
                      label: row.breakStart ?? '13:00',
                      onTap: onPickBreakStart,
                    ),
                    const Text(' – '),
                    _TimeButton(
                      label: row.breakEnd ?? '14:00',
                      onTap: onPickBreakEnd,
                    ),
                  ],
                  Switch(value: row.breakEnabled, onChanged: onToggleBreak),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _TimeButton extends StatelessWidget {
  const _TimeButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onTap,
      style: TextButton.styleFrom(
        minimumSize: const Size(56, 32),
        padding: const EdgeInsets.symmetric(horizontal: 8),
      ),
      child: Text(label),
    );
  }
}

class _NumberRow extends StatelessWidget {
  const _NumberRow({
    required this.label,
    required this.suffix,
    required this.hint,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  final String label;
  final String suffix;
  final String hint;
  final int value;
  final int min;
  final int max;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: theme.textTheme.bodyMedium),
                Text(
                  hint,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            width: 110,
            child: TextFormField(
              key: ValueKey('$label-$value'),
              initialValue: '$value',
              keyboardType: TextInputType.number,
              textAlign: TextAlign.end,
              decoration: InputDecoration(
                suffixText: suffix,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
              ),
              onChanged: (raw) {
                final parsed = int.tryParse(raw);
                // Sərhəddən kənar dəyər göndərilməsin — backend onsuz da
                // rədd edərdi, amma istifadəçi dərhal düzgün davransın.
                if (parsed != null && parsed >= min && parsed <= max) {
                  onChanged(parsed);
                }
              },
            ),
          ),
        ],
      ),
    );
  }
}

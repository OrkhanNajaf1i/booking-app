import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../models/availability.dart';

/// Bölmə başlığı.
class SectionLabel extends StatelessWidget {
  const SectionLabel({super.key, required this.label, required this.theme});

  final String label;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
    );
  }
}

/// Növbəti 14 günü göstərən üfüqi tarix zolağı.
class DateStrip extends StatelessWidget {
  const DateStrip({
    super.key,
    required this.selected,
    required this.onChanged,
    this.days = 14,
  });

  final DateTime selected;
  final ValueChanged<DateTime> onChanged;
  final int days;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final today = DateTime.now();

    return SizedBox(
      height: 72,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: days,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final date = DateTime(today.year, today.month, today.day + index);
          final isSelected = date.year == selected.year &&
              date.month == selected.month &&
              date.day == selected.day;

          return InkWell(
            onTap: () => onChanged(date),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: 60,
              decoration: BoxDecoration(
                color: isSelected ? theme.colorScheme.primary : null,
                border: Border.all(color: theme.colorScheme.outlineVariant),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    DateFormat('E', 'az').format(date),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: isSelected
                          ? theme.colorScheme.onPrimary
                          : theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${date.day}',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: isSelected ? theme.colorScheme.onPrimary : null,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Bir günün bütün vaxtları.
///
/// Tutulmuş vaxtlar da göstərilir (üstündən xətt ilə) — belə olanda
/// istifadəçi qrafikin sıxlığını görür və səbəbi tooltip-dən oxuyur.
class SlotGrid extends StatelessWidget {
  const SlotGrid({
    super.key,
    required this.loading,
    required this.day,
    required this.selected,
    required this.onSelect,
  });

  final bool loading;
  final DayAvailability? day;
  final TimeSlot? selected;
  final ValueChanged<TimeSlot> onSelect;

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 32),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (day == null || !day!.isWorkday) {
      return const EmptyState(
        icon: Icons.event_busy_outlined,
        message: 'Bu gün iş günü deyil',
      );
    }

    if (day!.slots.isEmpty) {
      return const EmptyState(
        icon: Icons.schedule_outlined,
        message: 'Bu gün üçün vaxt yoxdur',
      );
    }

    final formatter = DateFormat('HH:mm');

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: day!.slots.map((slot) {
        return _SlotChip(
          label: formatter.format(slot.start),
          available: slot.available,
          selected: selected?.start == slot.start,
          hint: slotStateLabel(slot.state),
          onTap: slot.available ? () => onSelect(slot) : null,
        );
      }).toList(),
    );
  }
}

class _SlotChip extends StatelessWidget {
  const _SlotChip({
    required this.label,
    required this.available,
    required this.selected,
    required this.hint,
    this.onTap,
  });

  final String label;
  final bool available;
  final bool selected;
  final String hint;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final Color background;
    final Color foreground;

    if (selected) {
      background = theme.colorScheme.primary;
      foreground = theme.colorScheme.onPrimary;
    } else if (available) {
      background = Colors.transparent;
      foreground = theme.colorScheme.onSurface;
    } else {
      background =
          theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4);
      foreground = theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5);
    }

    return Tooltip(
      message: available ? '' : hint,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: background,
            border: Border.all(
              color: selected
                  ? theme.colorScheme.primary
                  : theme.colorScheme.outlineVariant,
            ),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: foreground,
              fontWeight: selected ? FontWeight.w600 : null,
              decoration: available ? null : TextDecoration.lineThrough,
            ),
          ),
        ),
      ),
    );
  }
}

/// Seçim edildikdən sonra görünən təsdiq paneli.
class BookingBar extends StatelessWidget {
  const BookingBar({
    super.key,
    required this.label,
    required this.subtitle,
    required this.busy,
    required this.onConfirm,
  });

  final String label;
  final String subtitle;
  final bool busy;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      elevation: 8,
      color: theme.colorScheme.surface,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      label,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              FilledButton(
                onPressed: busy ? null : onConfirm,
                style: FilledButton.styleFrom(
                  minimumSize: const Size(140, 48),
                ),
                child: busy
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Bron et'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Boş vəziyyət göstəricisi.
class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Column(
        children: [
          Icon(icon, size: 36, color: theme.colorScheme.outline),
          const SizedBox(height: 10),
          Text(
            message,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

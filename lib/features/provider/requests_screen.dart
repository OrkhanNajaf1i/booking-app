import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../models/availability.dart';
import '../../models/booking.dart';
import '../../repositories/repositories.dart';
import '../../state/app_state.dart';

/// Provider (həkim, bərbər, usta) ekranı.
///
/// Müştəri bron edən kimi WebSocket hadisəsi gəlir, [BookingController]
/// siyahını özü yeniləyir — istifadəçi heç nə etməməlidir.
class RequestsScreen extends StatefulWidget {
  const RequestsScreen({super.key});

  @override
  State<RequestsScreen> createState() => _RequestsScreenState();
}

class _RequestsScreenState extends State<RequestsScreen> {
  static const _filters = <String?, String>{
    null: 'Hamısı',
    'pending': 'Təsdiq gözləyir',
    'confirmed': 'Təsdiqlənib',
    'reschedule_proposed': 'Təklif göndərilib',
    'cancelled': 'Ləğv edilib',
  };

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<BookingController>().refresh();
    });
  }

  Future<void> _run(Future<Booking> Function() action) async {
    final controller = context.read<BookingController>();
    final error = await controller.run(action);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(error ?? 'Yeniləndi')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<BookingController>();

    return Column(
      children: [
        // Filtr zolağı
        SizedBox(
          height: 52,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            children: _filters.entries.map((entry) {
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(entry.value),
                  selected: controller.statusFilter == entry.key,
                  onSelected: (_) => controller.setStatusFilter(entry.key),
                ),
              );
            }).toList(),
          ),
        ),

        Expanded(
          child: RefreshIndicator(
            onRefresh: controller.refresh,
            child: _buildList(controller),
          ),
        ),
      ],
    );
  }

  Widget _buildList(BookingController controller) {
    if (controller.isLoading && controller.bookings.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (controller.bookings.isEmpty) {
      // ListView lazımdır ki, boş halda da "aşağı çək" işləsin.
      return ListView(
        children: [
          const SizedBox(height: 80),
          Icon(
            Icons.inbox_outlined,
            size: 40,
            color: Theme.of(context).colorScheme.outline,
          ),
          const SizedBox(height: 12),
          Center(
            child: Text(
              controller.error ?? 'Bu filtrdə bron yoxdur',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: controller.bookings.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final booking = controller.bookings[index];
        return _BookingCard(
          booking: booking,
          onConfirm: () => _run(
            () => const BookingRepository().confirm(booking.id),
          ),
          onComplete: () => _run(
            () => const BookingRepository().complete(booking.id),
          ),
          onNoShow: () => _run(
            () => const BookingRepository().markNoShow(booking.id),
          ),
          onCancel: () => _run(
            () => const BookingRepository().cancel(booking.id),
          ),
          onPropose: () => _openProposeSheet(booking),
        );
      },
    );
  }

  Future<void> _openProposeSheet(Booking booking) async {
    final proposed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _ProposeSheet(booking: booking),
    );

    if (proposed == true && mounted) {
      await context.read<BookingController>().refresh();
    }
  }
}

// ═════════════════════════════════════════════════════════════
// BRON KARTI
// ═════════════════════════════════════════════════════════════

class _BookingCard extends StatelessWidget {
  const _BookingCard({
    required this.booking,
    required this.onConfirm,
    required this.onComplete,
    required this.onNoShow,
    required this.onCancel,
    required this.onPropose,
  });

  final Booking booking;
  final VoidCallback onConfirm;
  final VoidCallback onComplete;
  final VoidCallback onNoShow;
  final VoidCallback onCancel;
  final VoidCallback onPropose;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dateFormat = DateFormat('d MMMM, EEE', 'az');
    final timeFormat = DateFormat('HH:mm');

    final statusRaw = bookingStatusRaw(booking.status);
    final statusColor = AppTheme.statusColor(theme.colorScheme, statusRaw);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        dateFormat.format(booking.startTime),
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${timeFormat.format(booking.startTime)}–'
                        '${timeFormat.format(booking.endTime)} · '
                        '${booking.durationMins} dəq',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    bookingStatusLabel(booking.status),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: statusColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),

            if (booking.notes.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(booking.notes, style: theme.textTheme.bodySmall),
            ],

            if (booking.hasPendingProposal) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF0284C7).withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Təklif olunan vaxt: '
                      '${DateFormat('d MMM, HH:mm', 'az').format(booking.proposedStartTime!)}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (booking.proposalNote?.isNotEmpty == true)
                      Text(
                        booking.proposalNote!,
                        style: theme.textTheme.bodySmall,
                      ),
                    const SizedBox(height: 2),
                    Text(
                      'Müştərinin cavabı gözlənilir',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],

            if (booking.status == BookingStatus.cancelled &&
                booking.cancelReason?.isNotEmpty == true) ...[
              const SizedBox(height: 8),
              Text(
                'Səbəb: ${booking.cancelReason}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
            ],

            // Yalnız statusun icazə verdiyi əməliyyatlar göstərilir.
            if (booking.isActive) ...[
              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  if (booking.status == BookingStatus.pending)
                    FilledButton.tonalIcon(
                      onPressed: onConfirm,
                      icon: const Icon(Icons.check, size: 16),
                      label: const Text('Təsdiqlə'),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(0, 36),
                      ),
                    ),
                  if (booking.status == BookingStatus.pending ||
                      booking.status == BookingStatus.confirmed)
                    OutlinedButton.icon(
                      onPressed: onPropose,
                      icon: const Icon(Icons.schedule, size: 16),
                      label: const Text('Başqa vaxt'),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(0, 36),
                      ),
                    ),
                  if (booking.status == BookingStatus.confirmed) ...[
                    OutlinedButton(
                      onPressed: onComplete,
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(0, 36),
                      ),
                      child: const Text('Tamamlandı'),
                    ),
                    OutlinedButton(
                      onPressed: onNoShow,
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(0, 36),
                      ),
                      child: const Text('Gəlmədi'),
                    ),
                  ],
                  TextButton(
                    onPressed: onCancel,
                    style: TextButton.styleFrom(
                      minimumSize: const Size(0, 36),
                      foregroundColor: theme.colorScheme.error,
                    ),
                    child: const Text('Ləğv et'),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

}

// ═════════════════════════════════════════════════════════════
// ALTERNATİV VAXT TƏKLİFİ
// ═════════════════════════════════════════════════════════════

class _ProposeSheet extends StatefulWidget {
  const _ProposeSheet({required this.booking});

  final Booking booking;

  @override
  State<_ProposeSheet> createState() => _ProposeSheetState();
}

class _ProposeSheetState extends State<_ProposeSheet> {
  static const _availabilityRepo = AvailabilityRepository();
  static const _bookingRepo = BookingRepository();

  final _noteController = TextEditingController();

  late DateTime _date = widget.booking.startTime;
  DayAvailability? _day;
  TimeSlot? _selected;
  bool _loading = true;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _selected = null;
    });

    try {
      final result = await _availabilityRepo.getAvailability(
        staffId: widget.booking.staffId,
        serviceId: widget.booking.serviceId,
        from: _date,
        to: _date,
      );

      if (!mounted) return;
      setState(() {
        _day = result.days.isNotEmpty ? result.days.first : null;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _send() async {
    final slot = _selected;
    if (slot == null) return;

    setState(() => _sending = true);

    try {
      await _bookingRepo.proposeReschedule(
        widget.booking.id,
        newStart: slot.start,
        note: _noteController.text.trim(),
      );

      if (!mounted) return;
      Navigator.of(context).pop(true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Təklif göndərildi')),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _sending = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final timeFormat = DateFormat('HH:mm');

    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Alternativ vaxt təklif et',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),

            OutlinedButton.icon(
              onPressed: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _date,
                  firstDate: DateTime.now(),
                  lastDate: DateTime.now().add(const Duration(days: 60)),
                );
                if (picked != null) {
                  setState(() => _date = picked);
                  await _load();
                }
              },
              icon: const Icon(Icons.calendar_today, size: 16),
              label: Text(DateFormat('d MMMM yyyy', 'az').format(_date)),
            ),
            const SizedBox(height: 16),

            if (_loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_day == null || !_day!.isWorkday)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Text('Bu gün iş günü deyil'),
              )
            else ...[
              if (_day!.breakInfo != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    'Nahar fasiləsi: ${_day!.breakInfo!.start}–${_day!.breakInfo!.end}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 200),
                child: SingleChildScrollView(
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _day!.slots.map((slot) {
                      return ChoiceChip(
                        label: Text(timeFormat.format(slot.start)),
                        selected: _selected?.start == slot.start,
                        onSelected: slot.available
                            ? (_) => setState(() => _selected = slot)
                            : null,
                      );
                    }).toList(),
                  ),
                ),
              ),
            ],

            const SizedBox(height: 16),
            TextField(
              controller: _noteController,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Qeyd (müştəri görəcək)',
                hintText: 'Məsələn: həmin saat təcili iş düşdü',
              ),
            ),
            const SizedBox(height: 16),

            FilledButton(
              onPressed: _selected == null || _sending ? null : _send,
              child: _sending
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Təklifi göndər'),
            ),
          ],
        ),
      ),
    );
  }
}

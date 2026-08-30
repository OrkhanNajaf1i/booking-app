import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../models/booking.dart';
import '../../repositories/repositories.dart';
import '../../state/app_state.dart';

/// Müştərinin öz bronları.
///
/// Bərbər/həkim başqa vaxt təklif edəndə həmin bron kartında
/// "Qəbul et / İmtina et" düymələri çıxır — cavab anında geri gedir.
class MyBookingsScreen extends StatefulWidget {
  const MyBookingsScreen({super.key});

  @override
  State<MyBookingsScreen> createState() => _MyBookingsScreenState();
}

class _MyBookingsScreenState extends State<MyBookingsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<BookingController>().refresh();
    });
  }

  Future<void> _respond(Booking booking, {required bool accept}) async {
    final controller = context.read<BookingController>();

    final error = await controller.run(
      () => const BookingRepository().respondToProposal(
        booking.id,
        accept: accept,
      ),
    );

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          error ?? (accept ? 'Yeni vaxt təsdiqləndi' : 'Təklif rədd edildi'),
        ),
      ),
    );
  }

  Future<void> _cancel(Booking booking) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Bronu ləğv edim?'),
        content: const Text('Bu əməliyyat geri qaytarıla bilməz.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Xeyr'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Bəli, ləğv et'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final error = await context.read<BookingController>().run(
          () => const BookingRepository().cancel(booking.id),
        );

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(error ?? 'Bron ləğv edildi')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<BookingController>();
    final theme = Theme.of(context);

    if (controller.isLoading && controller.bookings.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    return RefreshIndicator(
      onRefresh: controller.refresh,
      child: controller.bookings.isEmpty
          ? ListView(
              children: [
                const SizedBox(height: 100),
                Icon(
                  Icons.event_note_outlined,
                  size: 40,
                  color: theme.colorScheme.outline,
                ),
                const SizedBox(height: 12),
                Center(
                  child: Text(
                    controller.error ?? 'Hələ bronunuz yoxdur',
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
              ],
            )
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: controller.bookings.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final booking = controller.bookings[index];
                return _MyBookingCard(
                  booking: booking,
                  onAccept: () => _respond(booking, accept: true),
                  onDecline: () => _respond(booking, accept: false),
                  onCancel: () => _cancel(booking),
                );
              },
            ),
    );
  }
}

class _MyBookingCard extends StatelessWidget {
  const _MyBookingCard({
    required this.booking,
    required this.onAccept,
    required this.onDecline,
    required this.onCancel,
  });

  final Booking booking;
  final VoidCallback onAccept;
  final VoidCallback onDecline;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dateFormat = DateFormat('d MMMM, EEE', 'az');
    final timeFormat = DateFormat('HH:mm');

    final statusColor = AppTheme.statusColor(
      theme.colorScheme,
      bookingStatusRaw(booking.status),
    );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
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
                      Text(
                        '${timeFormat.format(booking.startTime)}–'
                        '${timeFormat.format(booking.endTime)}',
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

            // Provider yeni vaxt təklif edib — cavab burada verilir.
            if (booking.hasPendingProposal) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF0284C7).withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Sizə yeni vaxt təklif olunub',
                      style: theme.textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      DateFormat('d MMMM, HH:mm', 'az')
                          .format(booking.proposedStartTime!),
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (booking.proposalNote?.isNotEmpty == true) ...[
                      const SizedBox(height: 4),
                      Text(
                        booking.proposalNote!,
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: FilledButton(
                            onPressed: onAccept,
                            style: FilledButton.styleFrom(
                              minimumSize: const Size(0, 40),
                            ),
                            child: const Text('Qəbul et'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton(
                            onPressed: onDecline,
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size(0, 40),
                            ),
                            child: const Text('İmtina'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],

            if (booking.isActive && !booking.hasPendingProposal) ...[
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: onCancel,
                  style: TextButton.styleFrom(
                    foregroundColor: theme.colorScheme.error,
                  ),
                  child: const Text('Ləğv et'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

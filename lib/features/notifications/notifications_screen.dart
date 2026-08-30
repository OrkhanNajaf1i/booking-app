import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/app_notification.dart';
import '../../state/app_state.dart';

/// Bildiriş mərkəzi.
///
/// Siyahı iki mənbədən dolur: açılışda backend-dən, sonra WebSocket-dən
/// gələn hər hadisə [NotificationController] tərəfindən başa əlavə olunur.
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<NotificationController>().refresh();
    });
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<NotificationController>();
    final theme = Theme.of(context);

    if (controller.isLoading && controller.items.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      children: [
        if (controller.unreadCount > 0)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Text(
                  '${controller.unreadCount} oxunmamış',
                  style: theme.textTheme.bodySmall,
                ),
                const Spacer(),
                TextButton(
                  onPressed: controller.markAllRead,
                  child: const Text('Hamısını oxu'),
                ),
              ],
            ),
          ),

        Expanded(
          child: RefreshIndicator(
            onRefresh: controller.refresh,
            child: controller.items.isEmpty
                ? ListView(
                    children: [
                      const SizedBox(height: 100),
                      Icon(
                        Icons.notifications_none,
                        size: 40,
                        color: theme.colorScheme.outline,
                      ),
                      const SizedBox(height: 12),
                      Center(
                        child: Text(
                          'Hələ bildiriş yoxdur',
                          style: theme.textTheme.bodyMedium,
                        ),
                      ),
                    ],
                  )
                : ListView.separated(
                    itemCount: controller.items.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final item = controller.items[index];
                      return _NotificationTile(item: item);
                    },
                  ),
          ),
        ),
      ],
    );
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({required this.item});

  final AppNotification item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      color: item.isRead
          ? null
          : theme.colorScheme.primaryContainer.withValues(alpha: 0.18),
      child: ListTile(
        leading: Text(
          notificationIcon(item.type),
          style: const TextStyle(fontSize: 22),
        ),
        title: Text(
          item.title,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: item.isRead ? FontWeight.w400 : FontWeight.w600,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(item.body),
            const SizedBox(height: 2),
            Text(
              _timeAgo(item.createdAt),
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
          ],
        ),
        isThreeLine: true,
      ),
    );
  }

  String _timeAgo(DateTime value) {
    final diff = DateTime.now().difference(value);

    if (diff.inMinutes < 1) return 'indicə';
    if (diff.inMinutes < 60) return '${diff.inMinutes} dəq əvvəl';
    if (diff.inHours < 24) return '${diff.inHours} saat əvvəl';
    if (diff.inDays < 7) return '${diff.inDays} gün əvvəl';

    return DateFormat('d MMM', 'az').format(value);
  }
}

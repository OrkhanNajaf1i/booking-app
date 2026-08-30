import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api/token_storage.dart';
import '../../core/realtime/realtime_service.dart';
import '../../state/app_state.dart';
import '../customer/book_screen.dart';
import '../customer/my_bookings_screen.dart';
import '../notifications/notifications_screen.dart';
import '../provider/requests_screen.dart';
import '../provider/schedule_screen.dart';

/// Ana çərçivə — alt naviqasiya rola görə qurulur.
///
/// Provider (həkim/bərbər/usta): Sorğular · Qrafik · Bildirişlər
/// Müştəri:                      Bron et · Bronlarım · Bildirişlər
class HomeShell extends StatefulWidget {
  const HomeShell({super.key, required this.claims});

  final SessionClaims claims;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> with WidgetsBindingObserver {
  int _index = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Tətbiq arxa plandan qayıdanda WebSocket çox güman qopub —
    // gecikmə gözləmədən bərpa edirik.
    if (state == AppLifecycleState.resumed) {
      RealtimeService.instance.reconnectNow();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isProvider = widget.claims.isProvider;
    final notifications = context.watch<NotificationController>();

    final tabs = isProvider
        ? const [
            _Tab(
              title: 'Bron sorğuları',
              icon: Icons.inbox_outlined,
              selectedIcon: Icons.inbox,
              label: 'Sorğular',
              body: RequestsScreen(),
            ),
            _Tab(
              title: 'İş qrafiki',
              icon: Icons.schedule_outlined,
              selectedIcon: Icons.schedule,
              label: 'Qrafik',
              body: ScheduleScreen(),
            ),
          ]
        : const [
            _Tab(
              title: 'Vaxt seç',
              icon: Icons.add_circle_outline,
              selectedIcon: Icons.add_circle,
              label: 'Bron et',
              body: BookScreen(),
            ),
            _Tab(
              title: 'Bronlarım',
              icon: Icons.event_note_outlined,
              selectedIcon: Icons.event_note,
              label: 'Bronlarım',
              body: MyBookingsScreen(),
            ),
          ];

    final allTabs = [
      ...tabs,
      const _Tab(
        title: 'Bildirişlər',
        icon: Icons.notifications_none,
        selectedIcon: Icons.notifications,
        label: 'Bildiriş',
        body: NotificationsScreen(),
      ),
    ];

    final current = allTabs[_index];

    return Scaffold(
      appBar: AppBar(
        title: Text(current.title),
        actions: [
          StreamBuilder<bool>(
            stream: RealtimeService.instance.connectionState,
            initialData: RealtimeService.instance.isConnected,
            builder: (context, snapshot) {
              final connected = snapshot.data ?? false;
              return Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Tooltip(
                  message: connected
                      ? 'Canlı bağlantı aktivdir'
                      : 'Bağlantı bərpa olunur…',
                  child: Icon(
                    connected ? Icons.cloud_done_outlined : Icons.cloud_off_outlined,
                    size: 20,
                    color: connected
                        ? const Color(0xFF059669)
                        : Theme.of(context).colorScheme.outline,
                  ),
                ),
              );
            },
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'logout') context.read<AuthController>().logout();
            },
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'logout', child: Text('Çıxış')),
            ],
          ),
        ],
      ),
      body: current.body,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (index) => setState(() => _index = index),
        destinations: [
          for (var i = 0; i < allTabs.length; i++)
            NavigationDestination(
              icon: _isLast(i, allTabs.length) && notifications.unreadCount > 0
                  ? Badge(
                      label: Text('${notifications.unreadCount}'),
                      child: Icon(allTabs[i].icon),
                    )
                  : Icon(allTabs[i].icon),
              selectedIcon: Icon(allTabs[i].selectedIcon),
              label: allTabs[i].label,
            ),
        ],
      ),
    );
  }

  bool _isLast(int index, int length) => index == length - 1;
}

class _Tab {
  const _Tab({
    required this.title,
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.body,
  });

  final String title;
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final Widget body;
}

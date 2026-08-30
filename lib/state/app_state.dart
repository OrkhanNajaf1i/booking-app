import 'dart:async';

import 'package:flutter/foundation.dart';

import '../core/api/api_client.dart';
import '../core/api/token_storage.dart';
import '../core/realtime/realtime_service.dart';
import '../models/app_notification.dart';
import '../models/booking.dart';
import '../repositories/repositories.dart';

// ═════════════════════════════════════════════════════════════
// AUTH
// ═════════════════════════════════════════════════════════════

class AuthController extends ChangeNotifier {
  AuthController(this._repository);

  final AuthRepository _repository;

  SessionClaims? _claims;
  bool _loading = false;
  String? _error;

  SessionClaims? get claims => _claims;
  bool get isLoading => _loading;
  String? get error => _error;
  bool get isSignedIn => _claims != null;

  /// Tətbiq açılanda saxlanılmış sessiyanı bərpa edir.
  Future<void> restore() async {
    await TokenStorage.instance.load();
    _claims = TokenStorage.instance.claims;

    if (_claims != null) RealtimeService.instance.start();
    notifyListeners();
  }

  Future<bool> login(String email, String password) async {
    _loading = true;
    _error = null;
    notifyListeners();

    try {
      _claims = await _repository.login(email: email, password: password);
      RealtimeService.instance.start();
      return true;
    } on ApiException catch (exception) {
      _error = exception.message;
      return false;
    } catch (_) {
      _error = 'Gözlənilməz xəta baş verdi';
      return false;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  /// Müştəri qeydiyyatı — uğurlu olsa dərhal sessiya açılır.
  Future<bool> register({
    required String fullName,
    required String email,
    required String phone,
    required String password,
  }) async {
    _loading = true;
    _error = null;
    notifyListeners();

    try {
      _claims = await _repository.register(
        fullName: fullName,
        email: email,
        phone: phone,
        password: password,
      );
      RealtimeService.instance.start();
      return true;
    } on ApiException catch (exception) {
      _error = exception.message;
      return false;
    } catch (_) {
      _error = 'Gözlənilməz xəta baş verdi';
      return false;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    await RealtimeService.instance.stop();
    await _repository.logout();
    _claims = null;
    notifyListeners();
  }

  /// Token bərpa oluna bilməyəndə interceptor bunu çağırır.
  void onSessionExpired() {
    _claims = null;
    RealtimeService.instance.stop();
    notifyListeners();
  }
}

// ═════════════════════════════════════════════════════════════
// NOTIFICATIONS
// ═════════════════════════════════════════════════════════════

class NotificationController extends ChangeNotifier {
  NotificationController(this._repository) {
    // Canlı hadisə gələn kimi siyahının başına əlavə olunur —
    // serverə yenidən sorğu göndərilmir.
    _subscription = RealtimeService.instance.events.listen((event) {
      if (event.isConnectionReady) return;

      _items.insert(0, AppNotification.fromEnvelope(event.raw));
      _unreadCount++;
      notifyListeners();
    });
  }

  final NotificationRepository _repository;
  late final StreamSubscription<RealtimeEvent> _subscription;

  final List<AppNotification> _items = [];
  int _unreadCount = 0;
  bool _loading = false;

  List<AppNotification> get items => List.unmodifiable(_items);
  int get unreadCount => _unreadCount;
  bool get isLoading => _loading;

  Future<void> refresh() async {
    _loading = true;
    notifyListeners();

    try {
      final result = await _repository.list();
      _items
        ..clear()
        ..addAll(result.items);
      _unreadCount = result.unreadCount;
    } on ApiException {
      // Bildiriş siyahısının yüklənməməsi ekranı bloklamamalıdır.
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> markAllRead() async {
    await _repository.markAllRead();
    _unreadCount = 0;
    await refresh();
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}

// ═════════════════════════════════════════════════════════════
// BOOKINGS
// ═════════════════════════════════════════════════════════════

/// Həm provider, həm müştəri siyahısını idarə edir.
///
/// [isProvider] true olanda biznesin bütün bronları, false olanda
/// istifadəçinin öz bronları yüklənir.
class BookingController extends ChangeNotifier {
  BookingController(this._repository, {required this.isProvider}) {
    _subscription = RealtimeService.instance.events.listen((event) {
      if (event.isConnectionReady) return;

      // Bron dəyişikliyi gələndə siyahı öz-özünə yenilənir —
      // istifadəçinin "aşağı çəkib yenilə" etməsinə ehtiyac qalmır.
      if (event.type.startsWith('booking.')) refresh();
    });
  }

  final BookingRepository _repository;
  final bool isProvider;
  late final StreamSubscription<RealtimeEvent> _subscription;

  List<Booking> _bookings = const [];
  bool _loading = false;
  String? _error;
  String? _statusFilter;

  List<Booking> get bookings => _bookings;
  bool get isLoading => _loading;
  String? get error => _error;
  String? get statusFilter => _statusFilter;

  /// Cavab gözləyən sorğular — provider ekranının əsas siyahısı.
  List<Booking> get pending => _bookings
      .where((booking) => booking.status == BookingStatus.pending)
      .toList();

  /// Müştəridən cavab gözlənilən təkliflər.
  List<Booking> get awaitingMyResponse =>
      _bookings.where((booking) => booking.hasPendingProposal).toList();

  void setStatusFilter(String? status) {
    _statusFilter = status;
    refresh();
  }

  Future<void> refresh() async {
    _loading = true;
    _error = null;
    notifyListeners();

    try {
      _bookings = isProvider
          ? await _repository.list(status: _statusFilter)
          : await _repository.listMine();
    } on ApiException catch (exception) {
      _error = exception.message;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  /// Əməliyyatı icra edir və siyahını yeniləyir.
  /// Uğurlu olsa null, əks halda xəta mətni qaytarır.
  Future<String?> run(Future<Booking> Function() action) async {
    try {
      await action();
      await refresh();
      return null;
    } on ApiException catch (exception) {
      // Vaxt aradan gedibsə siyahı köhnə qalmasın.
      if (exception.isSlotTaken) await refresh();
      return exception.message;
    } catch (_) {
      return 'Əməliyyat alınmadı';
    }
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}

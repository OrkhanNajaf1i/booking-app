import 'dart:async';
import 'dart:convert';

import 'package:web_socket_channel/web_socket_channel.dart';

import '../api/token_storage.dart';
import '../config/app_config.dart';

/// Backend-dən gələn canlı hadisə.
class RealtimeEvent {
  const RealtimeEvent({required this.type, required this.raw});

  final String type;
  final Map<String, dynamic> raw;

  /// Bağlantı qurulanda gələn ilk mesaj — bildiriş deyil.
  bool get isConnectionReady => type == 'connection.ready';
}

/// WebSocket bağlantısı.
///
/// Bağlantı qopanda eksponensial geri çəkilmə ilə özü qoşulur;
/// tətbiq arxa plandan qayıdanda [reconnectNow] ilə dərhal bərpa edilir.
class RealtimeService {
  RealtimeService._();

  static final RealtimeService instance = RealtimeService._();

  static const List<Duration> _backoff = [
    Duration(seconds: 1),
    Duration(seconds: 2),
    Duration(seconds: 5),
    Duration(seconds: 10),
    Duration(seconds: 30),
  ];

  final StreamController<RealtimeEvent> _events =
      StreamController<RealtimeEvent>.broadcast();
  final StreamController<bool> _connection =
      StreamController<bool>.broadcast();

  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _subscription;
  Timer? _retryTimer;
  int _attempt = 0;
  bool _disposed = false;
  bool _connected = false;

  /// Gələn hadisələr.
  Stream<RealtimeEvent> get events => _events.stream;

  /// Bağlantı vəziyyəti — UI-da "canlı" göstəricisi üçün.
  Stream<bool> get connectionState => _connection.stream;

  bool get isConnected => _connected;

  /// Login-dən sonra çağırılır.
  void start() {
    _disposed = false;
    _attempt = 0;
    _connect();
  }

  /// Logout-da çağırılır — yenidən qoşulma da dayanır.
  Future<void> stop() async {
    _disposed = true;
    _retryTimer?.cancel();
    _retryTimer = null;

    await _subscription?.cancel();
    _subscription = null;

    await _channel?.sink.close();
    _channel = null;

    _setConnected(false);
  }

  /// Tətbiq arxa plandan qayıdanda gecikmə gözləmədən bərpa edir.
  void reconnectNow() {
    if (_disposed || _connected) return;

    _retryTimer?.cancel();
    _attempt = 0;
    _connect();
  }

  void _connect() {
    if (_disposed) return;

    final token = TokenStorage.instance.accessToken;
    if (token == null) {
      // Hələ login yoxdur — sonra yenidən cəhd edilir.
      _scheduleRetry();
      return;
    }

    final url = '${AppConfig.wsBaseUrl}/ws?token=${Uri.encodeComponent(token)}';

    try {
      final channel = WebSocketChannel.connect(Uri.parse(url));
      _channel = channel;

      _subscription = channel.stream.listen(
        (message) {
          // İlk mesaj gələn kimi bağlantını "canlı" sayırıq.
          if (!_connected) {
            _attempt = 0;
            _setConnected(true);
          }
          _handleMessage(message);
        },
        onError: (_) => _handleDisconnect(),
        onDone: _handleDisconnect,
        cancelOnError: true,
      );
    } catch (_) {
      _handleDisconnect();
    }
  }

  void _handleMessage(dynamic message) {
    if (message is! String) return;

    try {
      final decoded = json.decode(message) as Map<String, dynamic>;
      final type = decoded['type'] as String? ?? '';

      _events.add(RealtimeEvent(type: type, raw: decoded));
    } catch (_) {
      // Formatı pozulmuş mesaj bağlantını qırmamalıdır.
    }
  }

  void _handleDisconnect() {
    _setConnected(false);
    _subscription?.cancel();
    _subscription = null;
    _channel = null;

    _scheduleRetry();
  }

  void _scheduleRetry() {
    if (_disposed) return;

    _retryTimer?.cancel();

    final delay = _backoff[_attempt < _backoff.length ? _attempt : _backoff.length - 1];
    _attempt++;

    _retryTimer = Timer(delay, _connect);
  }

  void _setConnected(bool value) {
    if (_connected == value) return;
    _connected = value;
    if (!_connection.isClosed) _connection.add(value);
  }
}

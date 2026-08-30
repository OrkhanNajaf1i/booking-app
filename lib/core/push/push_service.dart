import '../../repositories/repositories.dart';

/// Push bildirişləri (FCM) — tətbiq bağlı olanda xəbər çatdırmaq üçün.
///
/// Backend hazırdır: `POST /notifications/devices` token qəbul edir və
/// `notification_outbox` cədvəli vasitəsilə worker push göndərir.
/// Burada yalnız Firebase tərəfi qalıb.
///
/// AKTİVLƏŞDİRMƏ ADDIMLARI
/// ────────────────────────────────────────────────────────────
/// 1) `pubspec.yaml`-da firebase_core və firebase_messaging sətrlərinin
///    şərhini götürün, sonra `flutter pub get`.
///
/// 2) Firebase layihəsini bağlayın:
///        dart pub global activate flutterfire_cli
///        flutterfire configure
///    Bu, `lib/firebase_options.dart` faylını və platforma
///    konfiqurasiyalarını yaradır.
///
/// 3) `main.dart`-da runApp-dan əvvəl:
///        await Firebase.initializeApp(
///          options: DefaultFirebaseOptions.currentPlatform,
///        );
///
/// 4) Login-dən sonra `PushService.instance.register()` çağırın.
///
/// 5) Backend tərəfdə service account JSON-u verin:
///        APP_FCM_CREDENTIALS_FILE=/secrets/fcm.json
///    və ya
///        APP_FCM_CREDENTIALS_JSON='{"type":"service_account",...}'
///
/// Konfiqurasiya olmayanda backend push-u sadəcə söndürür —
/// WebSocket və in-app bildirişlər onsuz da işləyir.
class PushService {
  PushService._();

  static final PushService instance = PushService._();

  static const _repository = NotificationRepository();

  String? _token;

  /// Hazırda qeydiyyatdan keçmiş cihaz token-i.
  String? get token => _token;

  /// Firebase qoşulmayıbsa heç nə etmir.
  bool get isAvailable => false;

  /// İcazə istəyir, token alır və backend-də saxlayır.
  Future<void> register() async {
    // TODO(firebase): yuxarıdakı addımlar tamamlananda bu bloku açın.
    //
    // final messaging = FirebaseMessaging.instance;
    //
    // final settings = await messaging.requestPermission();
    // if (settings.authorizationStatus == AuthorizationStatus.denied) return;
    //
    // final token = await messaging.getToken();
    // if (token == null) return;
    //
    // _token = token;
    // await _repository.registerDevice(
    //   token,
    //   platform: Platform.isIOS ? 'ios' : 'android',
    // );
    //
    // // Token dövri olaraq yenilənir — hər dəfə backend-ə yazılmalıdır.
    // messaging.onTokenRefresh.listen((refreshed) async {
    //   _token = refreshed;
    //   await _repository.registerDevice(
    //     refreshed,
    //     platform: Platform.isIOS ? 'ios' : 'android',
    //   );
    // });
  }

  /// Çıxışda çağırılır — bu cihaza artıq push getməsin.
  Future<void> unregister() async {
    final token = _token;
    if (token == null) return;

    await _repository.unregisterDevice(token);
    _token = null;
  }
}

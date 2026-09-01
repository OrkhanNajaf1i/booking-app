/// Tətbiqin konfiqurasiyası.
///
/// Dəyərlər `--dart-define` ilə verilir ki, debug və prod build-ləri
/// eyni koddan çıxsın:
///
/// ```
/// flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8080/api/v1
/// ```
///
/// Android emulyatorunda `localhost` telefonun özünü göstərir;
/// host maşına çıxmaq üçün `10.0.2.2` işlədilir.
class AppConfig {
  const AppConfig._();

  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://booking-service-sld9.onrender.com/api/v1',
  );

  /// WebSocket URL-i API baza URL-indən çıxarılır (http→ws, https→wss).
  static String get wsBaseUrl => apiBaseUrl.replaceFirst(RegExp(r'^http'), 'ws');

  /// Bildiriş mətnlərindəki saatların göstərildiyi zona.
  static const String displayLocale = 'az';

  /// Şəbəkə sorğuları üçün gözləmə müddəti.
  static const Duration requestTimeout = Duration(seconds: 20);

  /// Cavabın gözlənildiyi müddət.
  ///
  /// Pulsuz hostinqdə server hərəkətsizlikdən yatır və ilk sorğuda
  /// oyanması yarım dəqiqəyə qədər çəkir. 20 saniyə ilə tətbiq həmin
  /// sorğunu həmişə "əlaqə yoxdur" kimi göstərirdi — istifadəçi isə
  /// bunu tətbiqin sınması kimi görür.
  static const Duration responseTimeout = Duration(seconds: 60);
}

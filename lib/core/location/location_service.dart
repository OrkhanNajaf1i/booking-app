import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'nearby_filter.dart';

/// Yer təyini — "yaxınlıqdakılar" süzgəci üçün.
///
/// İki yol var və ikisi də vacibdir:
///
/// 1. **Cihazın yeri** — bir toxunuşla. Amma icazə verilməyə bilər,
///    brauzerdə bloklana bilər, kənd yerində siqnal olmaya bilər.
/// 2. **Ünvanla axtarış** — istifadəçi "Nərimanov" yazır və siyahıdan
///    seçir. Bu, birinci yol işləməyəndə ekranı bağlamır.
///
/// Ona görə GPS xətası burada `LocationFailure` kimi qaytarılır, atılmır:
/// ekran həmişə əl ilə seçim təklif edə bilməlidir.
class LocationService {
  const LocationService();

  static const _prefsKey = 'nearby_filter';

  /// Nominatim pulsuzdur və API açarı istəmir; əvəzində saniyədə bir
  /// sorğu qaydası qoyur. Ona görə çağıran tərəf gecikdirmə tətbiq edir.
  static const _nominatim = 'https://nominatim.openstreetmap.org';

  /// Kənar xidmət üçün ayrıca, interceptor-suz Dio.
  ///
  /// `ApiClient.instance.dio` hər sorğuya bizim access token-i əlavə
  /// edir — onu üçüncü tərəfə göndərmək olmaz.
  static Dio get _plainDio => Dio(
        BaseOptions(
          connectTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 10),
          responseType: ResponseType.plain,
        ),
      );

  // ─── Cihazın yeri ──────────────────────────────────────────

  /// Cihazın cari koordinatı. Alınmasa səbəbi ilə birlikdə qaytarılır.
  Future<LocationResult> currentPosition() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        return const LocationResult.failure(
          'Cihazda yer xidməti sönülüdür. Ayarlardan açın və ya ünvanı '
          'əl ilə seçin.',
        );
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied) {
        return const LocationResult.failure(
          'Yerə icazə verilmədi. Ünvanı əl ilə seçə bilərsiniz.',
        );
      }
      if (permission == LocationPermission.deniedForever) {
        return const LocationResult.failure(
          'Yerə icazə həmişəlik bağlanıb. Tətbiq ayarlarından açın və ya '
          'ünvanı əl ilə seçin.',
        );
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          // Siqnal zəif olanda ekran sonsuz gözləməməlidir.
          timeLimit: Duration(seconds: 12),
        ),
      );

      return LocationResult.success(position.latitude, position.longitude);
    } on TimeoutException {
      return const LocationResult.failure(
        'Yer təyin edilə bilmədi. Ünvanı əl ilə seçin.',
      );
    } catch (error) {
      return LocationResult.failure('Yer alınmadı: $error');
    }
  }

  // ─── Ünvanla axtarış ───────────────────────────────────────

  /// Yazılan mətnə uyğun ünvanlar. Xəta olsa boş siyahı qayıdır —
  /// axtarış sahəsi istifadəçini bloklamamalıdır.
  Future<List<AddressSuggestion>> searchAddress(String query) async {
    final text = query.trim();
    if (text.length < 3) return const [];

    final uri = Uri.parse(
      '$_nominatim/search'
      '?format=jsonv2&addressdetails=1&limit=8&accept-language=az'
      // Axtarış Azərbaycanla məhdudlaşdırılıb: "Nərimanov" yazan adam
      // başqa ölkədəki eyniadlı yeri görməməlidir.
      '&countrycodes=az'
      '&q=${Uri.encodeQueryComponent(text)}',
    );

    try {
      final response = await _plainDio.getUri<String>(uri);
      if (response.statusCode != 200 || response.data == null) return const [];

      final decoded = jsonDecode(response.data!);
      if (decoded is! List) return const [];

      return decoded
          .whereType<Map<String, dynamic>>()
          .map(AddressSuggestion.fromJson)
          .where((item) => item != null)
          .cast<AddressSuggestion>()
          .toList();
    } catch (_) {
      return const [];
    }
  }

  /// Koordinatın oxunaqlı adı. Alınmasa null qayıdır və çağıran tərəf
  /// "Cari yerim" kimi ehtiyat ad işlədir.
  Future<String?> describe(double latitude, double longitude) async {
    final uri = Uri.parse(
      '$_nominatim/reverse'
      '?format=jsonv2&zoom=16&addressdetails=1&accept-language=az'
      '&lat=$latitude&lon=$longitude',
    );

    try {
      final response = await _plainDio.getUri<String>(uri);
      if (response.statusCode != 200 || response.data == null) return null;

      final decoded = jsonDecode(response.data!);
      if (decoded is! Map<String, dynamic>) return null;

      final address = decoded['address'];
      if (address is! Map<String, dynamic>) {
        return decoded['display_name'] as String?;
      }

      final parts = <String?>[
        address['suburb'] as String? ?? address['neighbourhood'] as String?,
        address['city'] as String? ??
            address['town'] as String? ??
            address['village'] as String?,
      ].where((item) => item != null && item.isNotEmpty).toList();

      if (parts.isEmpty) return decoded['display_name'] as String?;
      return parts.join(', ');
    } catch (_) {
      return null;
    }
  }

  // ─── Yaddaş ────────────────────────────────────────────────
  //
  // Seçim tətbiq bağlananda itməməlidir: adam hər dəfə eyni rayonu
  // yenidən seçmək istəmir.

  Future<void> save(NearbyFilter? filter) async {
    final prefs = await SharedPreferences.getInstance();
    if (filter == null) {
      await prefs.remove(_prefsKey);
      return;
    }
    await prefs.setString(_prefsKey, jsonEncode(filter.toJson()));
  }

  Future<NearbyFilter?> restore() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    if (raw == null) return null;

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return null;
      return NearbyFilter.fromJson(decoded);
    } catch (_) {
      return null;
    }
  }
}

/// GPS nəticəsi — uğur və ya oxunaqlı səbəb.
class LocationResult {
  const LocationResult.success(this.latitude, this.longitude) : error = null;
  const LocationResult.failure(this.error)
      : latitude = null,
        longitude = null;

  final double? latitude;
  final double? longitude;
  final String? error;

  bool get isSuccess => latitude != null && longitude != null;
}

/// Ünvan axtarışının bir nəticəsi.
class AddressSuggestion {
  const AddressSuggestion({
    required this.label,
    required this.latitude,
    required this.longitude,
  });

  final String label;
  final double latitude;
  final double longitude;

  static AddressSuggestion? fromJson(Map<String, dynamic> json) {
    final lat = double.tryParse('${json['lat']}');
    final lon = double.tryParse('${json['lon']}');
    if (lat == null || lon == null) return null;

    final display = json['display_name'] as String? ?? '';
    if (display.isEmpty) return null;

    // Nominatim tam ünvan qaytarır ("… , Azərbaycan"); siyahıda ilk iki
    // hissə kifayətdir, qalanı kartı uzadır.
    final parts = display.split(',').map((part) => part.trim()).toList();
    final label = parts.take(3).join(', ');

    return AddressSuggestion(label: label, latitude: lat, longitude: lon);
  }
}

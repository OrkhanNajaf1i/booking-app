import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// JWT-nin payload-ından çıxarılan istifadəçi məlumatı.
class SessionClaims {
  const SessionClaims({
    required this.userId,
    required this.role,
    this.businessId,
    this.email,
  });

  final String userId;
  final String role;
  final String? businessId;
  final String? email;

  /// Biznes tərəfi (sahib, işçi, solo praktik) — provider ekranlarını görür.
  bool get isProvider =>
      role == 'provider_owner' || role == 'staff' || role == 'solo_practitioner';

  /// Müştəri — bron etmə ekranlarını görür.
  bool get isCustomer => role == 'customer';
}

/// Access/refresh token-lərin yeganə saxlanma yeri.
///
/// Yaddaşda da kopyası saxlanılır ki, hər sorğuda disk oxunmasın.
class TokenStorage {
  TokenStorage._();

  static final TokenStorage instance = TokenStorage._();

  static const _accessKey = 'accessToken';
  static const _refreshKey = 'refreshToken';

  String? _accessToken;
  String? _refreshToken;
  bool _loaded = false;

  String? get accessToken => _accessToken;
  String? get refreshToken => _refreshToken;

  /// Tətbiq açılanda bir dəfə çağırılır.
  Future<void> load() async {
    if (_loaded) return;

    final prefs = await SharedPreferences.getInstance();
    _accessToken = prefs.getString(_accessKey);
    _refreshToken = prefs.getString(_refreshKey);
    _loaded = true;
  }

  Future<void> save({required String access, String? refresh}) async {
    _accessToken = access;
    if (refresh != null) _refreshToken = refresh;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_accessKey, access);
    if (refresh != null) await prefs.setString(_refreshKey, refresh);
  }

  Future<void> clear() async {
    _accessToken = null;
    _refreshToken = null;

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_accessKey);
    await prefs.remove(_refreshKey);
  }

  /// Access token-in içindəki claim-lər.
  ///
  /// İmza burada yoxlanılmır — bu, yalnız UI-ın hansı ekranı göstərəcəyini
  /// bilməsi üçündür. Səlahiyyət qərarını hər zaman backend verir.
  SessionClaims? get claims {
    final token = _accessToken;
    if (token == null) return null;

    try {
      final parts = token.split('.');
      if (parts.length != 3) return null;

      final payload = json.decode(
        utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))),
      ) as Map<String, dynamic>;

      final userId = payload['user_id'] as String?;
      if (userId == null) return null;

      return SessionClaims(
        userId: userId,
        role: (payload['role'] as String?) ?? 'customer',
        businessId: payload['business_id'] as String?,
        email: payload['email'] as String?,
      );
    } catch (_) {
      // Formatı pozulmuş token sadəcə "sessiya yoxdur" deməkdir.
      return null;
    }
  }
}

import '../core/api/api_client.dart';
import '../core/api/token_storage.dart';
import '../models/app_notification.dart';
import '../models/availability.dart';
import '../models/booking.dart';
import '../models/staff.dart';

/// Backend massiv qaytaranda bəzən birbaşa, bəzən `{data: [...]}` gəlir.
List<Map<String, dynamic>> _asList(dynamic payload) {
  if (payload is List) return payload.cast<Map<String, dynamic>>();

  if (payload is Map<String, dynamic> && payload['data'] is List) {
    return (payload['data'] as List).cast<Map<String, dynamic>>();
  }

  return const [];
}

// ═════════════════════════════════════════════════════════════
// AUTH
// ═════════════════════════════════════════════════════════════

class AuthRepository {
  const AuthRepository();

  Future<SessionClaims> login({
    required String email,
    required String password,
  }) async {
    final data = await ApiClient.instance.unwrap<Map<String, dynamic>>(
      ApiClient.instance.dio.post<dynamic>(
        '/auth/login',
        data: {'email': email, 'password': password},
      ),
    );

    final access = data['access_token'] as String?;
    if (access == null) {
      throw const ApiException(
        code: 'NO_TOKEN',
        message: 'Server token qaytarmadı',
      );
    }

    await TokenStorage.instance.save(
      access: access,
      refresh: data['refresh_token'] as String?,
    );

    final claims = TokenStorage.instance.claims;
    if (claims == null) {
      throw const ApiException(
        code: 'BAD_TOKEN',
        message: 'Token oxunmadı',
      );
    }
    return claims;
  }

  /// Müştəri qeydiyyatı.
  ///
  /// `account_type: customer` göndərilir — admin panel isə "provider"
  /// göndərir. Backend rolu buna görə təyin edir, ona görə istifadəçi
  /// səhv tərəfdə hesab açmır.
  Future<SessionClaims> register({
    required String fullName,
    required String email,
    required String phone,
    required String password,
  }) async {
    final data = await ApiClient.instance.unwrap<Map<String, dynamic>>(
      ApiClient.instance.dio.post<dynamic>(
        '/auth/register',
        data: {
          'full_name': fullName,
          'email': email,
          'phone': phone,
          'password': password,
          'account_type': 'customer',
        },
      ),
    );

    final access = data['access_token'] as String?;
    if (access == null) {
      throw const ApiException(
        code: 'NO_TOKEN',
        message: 'Server token qaytarmadı',
      );
    }

    await TokenStorage.instance.save(
      access: access,
      refresh: data['refresh_token'] as String?,
    );

    final claims = TokenStorage.instance.claims;
    if (claims == null) {
      throw const ApiException(code: 'BAD_TOKEN', message: 'Token oxunmadı');
    }
    return claims;
  }

  Future<void> logout() => TokenStorage.instance.clear();
}

// ═════════════════════════════════════════════════════════════
// AVAILABILITY
// ═════════════════════════════════════════════════════════════

class AvailabilityRepository {
  const AvailabilityRepository();

  /// Boş vaxtlar — hesablama backend-də olur, keşlənmir.
  Future<AvailabilityResult> getAvailability({
    required String staffId,
    String? serviceId,
    DateTime? from,
    DateTime? to,
  }) async {
    String? asDate(DateTime? value) =>
        value?.toIso8601String().substring(0, 10);

    final data = await ApiClient.instance.unwrap<Map<String, dynamic>>(
      ApiClient.instance.dio.get<dynamic>(
        '/availability',
        queryParameters: {
          'staff_id': staffId,
          if (serviceId != null) 'service_id': serviceId,
          if (from != null) 'from': asDate(from),
          if (to != null) 'to': asDate(to),
        },
      ),
    );

    return AvailabilityResult.fromJson(data);
  }

  Future<List<WorkingHours>> listWorkingHours(String staffId) async {
    final data = await ApiClient.instance.unwrap<dynamic>(
      ApiClient.instance.dio.get<dynamic>(
        '/availability/working-hours',
        queryParameters: {'staff_id': staffId},
      ),
    );

    return _asList(data).map(WorkingHours.fromJson).toList();
  }

  /// Bütün həftəni bir sorğuda yazır.
  Future<void> saveWeek(String staffId, List<WorkingHours> week) async {
    await ApiClient.instance.unwrap<dynamic>(
      ApiClient.instance.dio.put<dynamic>(
        '/availability/working-hours',
        data: {
          'staff_id': staffId,
          'days': week.map((day) => day.toJson(staffId)).toList(),
        },
      ),
    );
  }

  Future<ScheduleSettings> getSettings({String? staffId}) async {
    final data = await ApiClient.instance.unwrap<Map<String, dynamic>>(
      ApiClient.instance.dio.get<dynamic>(
        '/availability/settings',
        queryParameters: staffId == null ? null : {'staff_id': staffId},
      ),
    );

    return ScheduleSettings.fromJson(data);
  }

  Future<ScheduleSettings> updateSettings(
    ScheduleSettings settings, {
    String? staffId,
  }) async {
    final data = await ApiClient.instance.unwrap<Map<String, dynamic>>(
      ApiClient.instance.dio.put<dynamic>(
        '/availability/settings',
        data: settings.toJson(staffId: staffId),
      ),
    );

    return ScheduleSettings.fromJson(data);
  }
}

// ═════════════════════════════════════════════════════════════
// BOOKING
// ═════════════════════════════════════════════════════════════

class BookingRepository {
  const BookingRepository();

  /// Biznes tərəfi: gələn sorğular.
  Future<List<Booking>> list({String? status, String? staffId}) async {
    final data = await ApiClient.instance.unwrap<dynamic>(
      ApiClient.instance.dio.get<dynamic>(
        '/bookings',
        queryParameters: {
          if (status != null) 'status': status,
          if (staffId != null) 'staff_id': staffId,
        },
      ),
    );

    return _asList(data).map(Booking.fromJson).toList();
  }

  /// Müştəri tərəfi: öz bronları.
  Future<List<Booking>> listMine() async {
    final data = await ApiClient.instance.unwrap<dynamic>(
      ApiClient.instance.dio.get<dynamic>('/bookings/my'),
    );

    return _asList(data).map(Booking.fromJson).toList();
  }

  Future<Booking> create({
    required String customerId,
    required String staffId,
    required DateTime startTime,
    String? serviceId,
    String notes = '',
  }) async {
    final data = await ApiClient.instance.unwrap<Map<String, dynamic>>(
      ApiClient.instance.dio.post<dynamic>(
        '/bookings',
        data: {
          'customer_id': customerId,
          'staff_id': staffId,
          if (serviceId != null) 'service_id': serviceId,
          'start_time': startTime.toUtc().toIso8601String(),
          'notes': notes,
        },
      ),
    );

    return Booking.fromJson(data);
  }

  // ─── Provider ────────────────────────────────────────────

  Future<Booking> confirm(String id) => _post('/bookings/$id/confirm');

  /// Alternativ vaxt təklifi — müştəriyə anında bildiriş gedir.
  Future<Booking> proposeReschedule(
    String id, {
    required DateTime newStart,
    String note = '',
  }) =>
      _post(
        '/bookings/$id/propose',
        body: {
          'new_start_time': newStart.toUtc().toIso8601String(),
          'note': note,
        },
      );

  Future<Booking> complete(String id) => _post('/bookings/$id/complete');

  Future<Booking> markNoShow(String id) => _post('/bookings/$id/no-show');

  // ─── Müştəri ─────────────────────────────────────────────

  Future<Booking> respondToProposal(
    String id, {
    required bool accept,
    String note = '',
  }) =>
      _post(
        '/bookings/$id/respond',
        body: {'accept': accept, 'note': note},
      );

  Future<Booking> cancel(String id, {String reason = ''}) =>
      _post('/bookings/$id/cancel', body: {'reason': reason});

  Future<Booking> _post(String path, {Map<String, dynamic>? body}) async {
    final data = await ApiClient.instance.unwrap<Map<String, dynamic>>(
      ApiClient.instance.dio.post<dynamic>(path, data: body),
    );
    return Booking.fromJson(data);
  }
}

// ═════════════════════════════════════════════════════════════
// PUBLIC (kəşf) — login tələb etmir
// ═════════════════════════════════════════════════════════════

/// Müştəri hansı xəstəxana/bərbərdə bron edəcəyini burada seçir.
/// JWT-də biznes olmadığı üçün bu endpoint-lər business_id-ni açıq alır.
class PublicRepository {
  const PublicRepository();

  /// Xidmət sahələri — hər birində neçə biznes olduğu ilə.
  Future<List<ServiceCategory>> listCategories() async {
    final data = await ApiClient.instance.unwrap<dynamic>(
      ApiClient.instance.dio.get<dynamic>('/public/categories'),
    );
    return _asList(data).map(ServiceCategory.fromJson).toList();
  }

  /// Bizneslər. [category] verilsə yalnız həmin sahə, [query] verilsə
  /// ad/sahə üzrə axtarış.
  Future<List<BusinessCard>> listBusinesses({
    String? category,
    String? query,
  }) async {
    final data = await ApiClient.instance.unwrap<dynamic>(
      ApiClient.instance.dio.get<dynamic>(
        '/public/businesses',
        queryParameters: {
          if (category != null && category.isNotEmpty) 'category': category,
          if (query != null && query.trim().isNotEmpty) 'q': query.trim(),
        },
      ),
    );
    return _asList(data).map(BusinessCard.fromJson).toList();
  }

  Future<List<StaffMember>> listStaff(String businessId) async {
    final data = await ApiClient.instance.unwrap<dynamic>(
      ApiClient.instance.dio.get<dynamic>('/public/businesses/$businessId/staff'),
    );

    // Public cavabda business_id yoxdur — kontekstdən doldururuq.
    return _asList(data)
        .map((json) => StaffMember.fromJson({...json, 'business_id': businessId}))
        .toList();
  }

  Future<List<ServiceItem>> listServices(
    String businessId, {
    String? staffId,
  }) async {
    final data = await ApiClient.instance.unwrap<dynamic>(
      ApiClient.instance.dio.get<dynamic>(
        '/public/businesses/$businessId/services',
        queryParameters: staffId == null ? null : {'staff_id': staffId},
      ),
    );
    return _asList(data).map(ServiceItem.fromJson).toList();
  }

  /// Boş vaxtlar — qorunan variantdan fərqi business_id-nin açıq verilməsidir.
  Future<AvailabilityResult> getAvailability({
    required String businessId,
    required String staffId,
    String? serviceId,
    DateTime? from,
    DateTime? to,
  }) async {
    String? asDate(DateTime? value) =>
        value?.toIso8601String().substring(0, 10);

    final data = await ApiClient.instance.unwrap<Map<String, dynamic>>(
      ApiClient.instance.dio.get<dynamic>(
        '/public/availability',
        queryParameters: {
          'business_id': businessId,
          'staff_id': staffId,
          if (serviceId != null) 'service_id': serviceId,
          if (from != null) 'from': asDate(from),
          if (to != null) 'to': asDate(to),
        },
      ),
    );

    return AvailabilityResult.fromJson(data);
  }
}

// ═════════════════════════════════════════════════════════════
// CUSTOMER
// ═════════════════════════════════════════════════════════════

class CustomerRepository {
  const CustomerRepository();

  /// Login olmuş istifadəçinin həmin biznesdəki müştəri kartını qaytarır
  /// (yoxdursa yaradır). Bron `customer_id` tələb etdiyi üçün lazımdır.
  Future<String> resolveSelfId(String businessId) async {
    final data = await ApiClient.instance.unwrap<Map<String, dynamic>>(
      ApiClient.instance.dio.post<dynamic>(
        '/customers/self',
        data: {'business_id': businessId},
      ),
    );

    final id = data['id'] as String?;
    if (id == null) {
      throw const ApiException(
        code: 'CUSTOMER_NOT_FOUND',
        message: 'Müştəri kartı yaradıla bilmədi',
      );
    }
    return id;
  }
}

// ═════════════════════════════════════════════════════════════
// STAFF / SERVICE
// ═════════════════════════════════════════════════════════════

class StaffRepository {
  const StaffRepository();

  Future<List<StaffMember>> list() async {
    final data = await ApiClient.instance.unwrap<dynamic>(
      ApiClient.instance.dio.get<dynamic>('/staff'),
    );
    return _asList(data).map(StaffMember.fromJson).toList();
  }

  Future<List<ServiceItem>> listServices() async {
    final data = await ApiClient.instance.unwrap<dynamic>(
      ApiClient.instance.dio.get<dynamic>('/services'),
    );
    return _asList(data).map(ServiceItem.fromJson).toList();
  }

  Future<List<ServiceItem>> listStaffServices(String staffId) async {
    final data = await ApiClient.instance.unwrap<dynamic>(
      ApiClient.instance.dio.get<dynamic>('/staff/$staffId/services'),
    );
    return _asList(data).map(ServiceItem.fromJson).toList();
  }
}

// ═════════════════════════════════════════════════════════════
// NOTIFICATION
// ═════════════════════════════════════════════════════════════

class NotificationRepository {
  const NotificationRepository();

  Future<({List<AppNotification> items, int unreadCount})> list({
    bool unreadOnly = false,
    int limit = 30,
  }) async {
    final data = await ApiClient.instance.unwrap<Map<String, dynamic>>(
      ApiClient.instance.dio.get<dynamic>(
        '/notifications',
        queryParameters: {
          if (unreadOnly) 'unread': true,
          'limit': limit,
        },
      ),
    );

    final items = _asList(data['items']).map(AppNotification.fromJson).toList();
    final unread = (data['unread_count'] as num?)?.toInt() ?? 0;

    return (items: items, unreadCount: unread);
  }

  Future<void> markRead(String id) async {
    await ApiClient.instance.unwrap<dynamic>(
      ApiClient.instance.dio.post<dynamic>('/notifications/$id/read'),
    );
  }

  Future<void> markAllRead() async {
    await ApiClient.instance.unwrap<dynamic>(
      ApiClient.instance.dio.post<dynamic>('/notifications/read-all'),
    );
  }

  /// FCM token-i backend-də saxlayır ki, tətbiq bağlı olanda push gəlsin.
  Future<void> registerDevice(String token, {String platform = 'android'}) async {
    await ApiClient.instance.unwrap<dynamic>(
      ApiClient.instance.dio.post<dynamic>(
        '/notifications/devices',
        data: {'token': token, 'platform': platform},
      ),
    );
  }

  Future<void> unregisterDevice(String token) async {
    await ApiClient.instance.unwrap<dynamic>(
      ApiClient.instance.dio.delete<dynamic>(
        '/notifications/devices',
        queryParameters: {'token': token},
      ),
    );
  }
}

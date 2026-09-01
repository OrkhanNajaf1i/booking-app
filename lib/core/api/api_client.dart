import 'dart:async';

import 'package:dio/dio.dart';

import '../config/app_config.dart';
import 'token_storage.dart';

/// Backend-in xəta formatı: `{success:false, code:"SLOT_TAKEN", message:"..."}`.
class ApiException implements Exception {
  const ApiException({required this.code, required this.message, this.status});

  final String code;
  final String message;
  final int? status;

  /// Vaxt artıq tutulub — UI bu halda siyahını yeniləyib istifadəçini
  /// başqa saat seçməyə yönləndirməlidir.
  bool get isSlotTaken => code == 'SLOT_TAKEN' || code == 'SLOT_BLOCKED';

  @override
  String toString() => message;
}

/// Tətbiqin yeganə HTTP client-i.
///
/// `validateStatus` bütün <500 statusları "uğurlu" sayır ki, cavab
/// `onResponse`-a çatsın və xətanı biz normallaşdıra bilək.
/// 401 gələndə token yenilənir və sorğu bir dəfə təkrarlanır.
class ApiClient {
  ApiClient._() {
    _dio = Dio(
      BaseOptions(
        baseUrl: AppConfig.apiBaseUrl,
        connectTimeout: AppConfig.requestTimeout,
        receiveTimeout: AppConfig.responseTimeout,
        headers: {'Content-Type': 'application/json'},
        validateStatus: (status) => status != null && status < 500,
      ),
    );

    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          // Auth endpoint-lerine kohne token qosulmamalidir: onlar
          // sessiya yaradir, sessiya teleb etmir. Kohne/expired token
          // gonderilse serverin davranisi qeyri-muyyen olur.
          if (!_isAuthEndpoint(options.path)) {
            final token = TokenStorage.instance.accessToken;
            if (token != null) {
              options.headers['Authorization'] = 'Bearer $token';
            }
          }
          handler.next(options);
        },

        // Bütün emal burada aparılır: reject-in onError-a ötürülməsi
        // Dio-da interceptor sırasından asılıdır, ona görə ona bel bağlamırıq.
        onResponse: (response, handler) async {
          final status = response.statusCode ?? 0;

          if (status < 400) {
            handler.next(response);
            return;
          }

          final options = response.requestOptions;
          final alreadyRetried = options.extra['__retried'] == true;

          // 401 → refresh → bir dəfə təkrar.
          //
          // Auth endpoint-leri istisnadir: /auth/login 401 qaytaranda bu
          // "parol yanlisdir" demekdir, "sessiya bitib" yox. Refresh
          // cehdi menasizdir ve istifadeci serverin esl mesaji evezine
          // "Sessiya bitib" gorur.
          if (status == 401 && !alreadyRetried && !_isAuthEndpoint(options.path)) {
            final refreshed = await _refreshToken();

            if (!refreshed) {
              await TokenStorage.instance.clear();
              onUnauthorized?.call();
              handler.reject(
                DioException(
                  requestOptions: options,
                  response: response,
                  type: DioExceptionType.badResponse,
                  error: const ApiException(
                    code: 'UNAUTHORIZED',
                    message: 'Sessiya bitib, yenidən daxil olun',
                    status: 401,
                  ),
                ),
                true,
              );
              return;
            }

            try {
              options.extra['__retried'] = true;
              options.headers['Authorization'] =
                  'Bearer ${TokenStorage.instance.accessToken}';

              final retried = await _dio.fetch<dynamic>(options);
              handler.resolve(retried);
            } catch (error) {
              handler.reject(
                error is DioException
                    ? error
                    : DioException(requestOptions: options, error: error),
                true,
              );
            }
            return;
          }

          handler.reject(
            DioException(
              requestOptions: options,
              response: response,
              type: DioExceptionType.badResponse,
              error: _toApiException(response),
            ),
            true,
          );
        },

        // Buraya yalnız şəbəkə/timeout xətaları düşür.
        onError: (error, handler) {
          if (error.error is ApiException) {
            handler.next(error);
            return;
          }

          handler.reject(
            DioException(
              requestOptions: error.requestOptions,
              response: error.response,
              type: error.type,
              error: const ApiException(
                code: 'NETWORK_ERROR',
                message: 'İnternet bağlantısı yoxdur',
              ),
            ),
          );
        },
      ),
    );
  }

  /// Sessiya teleb etmeyen endpoint-ler.
  static bool _isAuthEndpoint(String path) {
    return path.startsWith('/auth/') || path.startsWith('/public/');
  }

  static final ApiClient instance = ApiClient._();

  late final Dio _dio;

  /// Sessiya bərpa oluna bilməyəndə çağırılır — tətbiq login-ə qayıdır.
  void Function()? onUnauthorized;

  Dio get dio => _dio;

  // ─── Refresh ───────────────────────────────────────────────

  /// Paralel 401-lər eyni anda refresh etməsin deyə tək Future paylaşılır.
  Future<bool>? _refreshInFlight;

  Future<bool> _refreshToken() {
    return _refreshInFlight ??= _doRefresh().whenComplete(() {
      _refreshInFlight = null;
    });
  }

  Future<bool> _doRefresh() async {
    final refresh = TokenStorage.instance.refreshToken;
    if (refresh == null) return false;

    try {
      // Ayrı Dio: interceptor döngüsünə düşməsin.
      final plain = Dio(BaseOptions(baseUrl: AppConfig.apiBaseUrl));
      final response = await plain.post<Map<String, dynamic>>(
        '/auth/refresh',
        data: {'refresh_token': refresh},
      );

      final data = response.data?['data'] as Map<String, dynamic>?;
      final access = data?['access_token'] as String?;
      if (access == null) return false;

      await TokenStorage.instance.save(
        access: access,
        refresh: data?['refresh_token'] as String?,
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  // ─── Köməkçi metodlar ──────────────────────────────────────

  /// Backend `{success, data}` zərfi qaytarır; `data`-nı açır.
  /// Xətanı hər zaman [ApiException] kimi atır.
  Future<T> unwrap<T>(Future<Response<dynamic>> request) async {
    try {
      final response = await request;
      final body = response.data;

      if (body is Map<String, dynamic> && body.containsKey('data')) {
        return body['data'] as T;
      }
      return body as T;
    } on DioException catch (error) {
      if (error.error is ApiException) throw error.error! as ApiException;

      final response = error.response;
      if (response != null) throw _toApiException(response);

      throw const ApiException(
        code: 'NETWORK_ERROR',
        message: 'İnternet bağlantısı yoxdur',
      );
    }
  }

  static ApiException _toApiException(Response<dynamic> response) {
    final body = response.data;

    if (body is Map<String, dynamic>) {
      return ApiException(
        code: (body['code'] as String?) ?? 'UNKNOWN_ERROR',
        message: (body['message'] as String?) ?? 'Xəta baş verdi',
        status: response.statusCode,
      );
    }

    return ApiException(
      code: 'UNKNOWN_ERROR',
      message: 'Xəta baş verdi',
      status: response.statusCode,
    );
  }
}

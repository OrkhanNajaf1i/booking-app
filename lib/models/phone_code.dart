/// Kod göndərmə sorğusunun nəticəsi.
///
/// Server nömrəni normallaşdırır: təsdiq addımında istifadəçinin
/// yazdığı deyil, **buradakı** [phone] göndərilməlidir — əks halda
/// "050…" ilə istənilən kod "+994 50…" ilə təsdiqlənməyə çalışılar.
class PhoneCodeRequest {
  const PhoneCodeRequest({
    required this.phone,
    required this.maskedPhone,
    required this.expiresIn,
    required this.resendAfter,
    required this.channel,
    this.debugCode,
  });

  /// Normallaşdırılmış nömrə (+994XXXXXXXXX).
  final String phone;

  /// Ekranda göstərilən forma: "+994 50 *** ** 33".
  final String maskedPhone;

  /// Kodun neçə saniyə etibarlı olduğu.
  final int expiresIn;

  /// Yeni kod üçün neçə saniyə gözləmək lazımdır.
  final int resendAfter;

  /// Kodun hansı yolla getdiyi: sms / whatsapp / log.
  final String channel;

  /// Yalnız inkişaf rejimində (`log` kanalı) dolur.
  /// Real kanalda həmişə null-dur.
  final String? debugCode;

  bool get isDevelopmentChannel => channel == 'log';

  factory PhoneCodeRequest.fromJson(Map<String, dynamic> json) =>
      PhoneCodeRequest(
        phone: json['phone'] as String? ?? '',
        maskedPhone: json['masked_phone'] as String? ?? '',
        expiresIn: (json['expires_in'] as num?)?.toInt() ?? 300,
        resendAfter: (json['resend_after'] as num?)?.toInt() ?? 60,
        channel: json['channel'] as String? ?? 'sms',
        debugCode: json['debug_code'] as String?,
      );
}

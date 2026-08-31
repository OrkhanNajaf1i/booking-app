/// Müştərinin "haradayam" seçimi.
///
/// İki yolla dolur: cihazın GPS-i və ya əl ilə seçilmiş ünvan. Kəşf
/// ekranı hansı yolla gəldiyini bilmir — hər ikisi eyni sorğu
/// parametrlərinə çevrilir.
class NearbyFilter {
  const NearbyFilter({
    required this.latitude,
    required this.longitude,
    required this.radiusKm,
    required this.label,
  });

  final double latitude;
  final double longitude;

  /// Bu məsafədən uzaqdakılar siyahıdan çıxarılır.
  final double radiusKm;

  /// İstifadəçiyə göstərilən ad — "Cari yerim" və ya seçilmiş ünvan.
  final String label;

  /// Seçilə bilən radiuslar. Şəhərdaxili axtarış üçün 2 km, kənd/rayon
  /// üçün 50 km-ə qədər məna kəsb edir.
  static const radiusOptions = <double>[2, 5, 10, 25, 50];

  NearbyFilter copyWith({double? radiusKm}) => NearbyFilter(
        latitude: latitude,
        longitude: longitude,
        radiusKm: radiusKm ?? this.radiusKm,
        label: label,
      );

  Map<String, dynamic> toQuery() => {
        'lat': latitude.toStringAsFixed(6),
        'lng': longitude.toStringAsFixed(6),
        'radius_km': radiusKm.toStringAsFixed(1),
      };

  Map<String, dynamic> toJson() => {
        'lat': latitude,
        'lng': longitude,
        'radius_km': radiusKm,
        'label': label,
      };

  static NearbyFilter? fromJson(Map<String, dynamic> json) {
    final lat = (json['lat'] as num?)?.toDouble();
    final lng = (json['lng'] as num?)?.toDouble();
    if (lat == null || lng == null) return null;

    return NearbyFilter(
      latitude: lat,
      longitude: lng,
      radiusKm: (json['radius_km'] as num?)?.toDouble() ?? 10,
      label: json['label'] as String? ?? '',
    );
  }

  String get radiusLabel => radiusKm >= 1
      ? '${radiusKm.toStringAsFixed(0)} km'
      : '${(radiusKm * 1000).round()} m';

  /// Seçim pəncərəsinin "süzgəci sil" cavabı.
  ///
  /// `null` artıq "pəncərə bağlandı, heç nə dəyişmə" mənasını daşıyır —
  /// silməni ondan ayırmaq üçün ayrıca dəyər lazımdır.
  static const cleared = NearbyFilter(
    latitude: double.nan,
    longitude: double.nan,
    radiusKm: 0,
    label: '',
  );

  bool get isCleared => latitude.isNaN;
}

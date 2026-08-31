/// Xidmət sahəsi — müştəri əvvəlcə bunu seçir (Bərbər, Diş Həkimi…).
///
/// Ayrıca cədvəl deyil: bizneslərin `service_category` sahəsindən
/// yığılır, ona görə yeni sahə əlavə etmək üçün kod dəyişmir.
class ServiceCategory {
  const ServiceCategory({
    required this.slug,
    required this.name,
    required this.count,
    this.icon = '',
  });

  /// Filtrdə işlənən dəyişməz açar ("dentist").
  /// Ad tərcümə oluna bilər, slug yox — filtr buna bağlanır.
  final String slug;

  final String name;

  /// Serverdən gələn ikon açarı — admin panel ilə eyni adlandırma.
  final String icon;

  /// Bu sahədə neçə aktiv biznes var.
  final int count;

  factory ServiceCategory.fromJson(Map<String, dynamic> json) =>
      ServiceCategory(
        slug: json['slug'] as String? ?? '',
        name: json['name'] as String? ?? '',
        icon: json['icon'] as String? ?? '',
        count: (json['count'] as num?)?.toInt() ?? 0,
      );
}

/// Biznes (xəstəxana, klinika, bərbərxana, usta).
class BusinessCard {
  const BusinessCard({
    required this.id,
    required this.name,
    this.category = '',
    this.categoryName = '',
    this.categoryIcon = '',
    this.industry = '',
    this.serviceCategory = '',
    this.phone = '',
    this.businessType = '',
    this.city = '',
    this.address = '',
    this.distanceKm,
    this.latitude,
    this.longitude,
  });

  final String id;
  final String name;

  /// Sabit kateqoriya slug-ı — qruplaşdırma buna görə gedir.
  final String category;
  final String categoryName;
  final String categoryIcon;

  final String industry;

  /// Sahibin öz sözü ("Kardioloq") — kateqoriyadan daha dəqiqdir.
  final String serviceCategory;

  final String phone;
  final String businessType;

  final String city;
  final String address;

  /// Yalnız sorğuda koordinat göndəriləndə dolur.
  final double? distanceKm;

  /// Filialın xəritə koordinatı. Sahib xəritədə yer seçməyibsə boş
  /// olur — belə biznes yalnız siyahıda görünür.
  final double? latitude;
  final double? longitude;

  bool get hasCoordinates => latitude != null && longitude != null;

  /// Kartın altında göstərilən sahə etiketi.
  ///
  /// İxtisas varsa o üstündür: "Kardioloq" müştəri üçün "Həkim"dən
  /// daha məlumatlıdır.
  String get subtitle {
    if (serviceCategory.isNotEmpty) return serviceCategory;
    if (categoryName.isNotEmpty) return categoryName;
    if (industry.isNotEmpty) return industry;
    return '';
  }

  /// "1.2 km" / "350 m" — kilometrin altı metrlə daha oxunaqlıdır.
  String? get distanceLabel {
    final value = distanceKm;
    if (value == null) return null;
    if (value < 1) return '${(value * 1000).round()} m';
    return '${value.toStringAsFixed(1)} km';
  }

  factory BusinessCard.fromJson(Map<String, dynamic> json) => BusinessCard(
        id: json['id'] as String,
        name: json['name'] as String? ?? '',
        category: json['category'] as String? ?? '',
        categoryName: json['category_name'] as String? ?? '',
        categoryIcon: json['category_icon'] as String? ?? '',
        industry: json['industry'] as String? ?? '',
        serviceCategory: json['service_category'] as String? ?? '',
        phone: json['phone'] as String? ?? '',
        businessType: json['business_type'] as String? ?? '',
        city: json['city'] as String? ?? '',
        address: json['address'] as String? ?? '',
        distanceKm: (json['distance_km'] as num?)?.toDouble(),
        latitude: (json['latitude'] as num?)?.toDouble(),
        longitude: (json['longitude'] as num?)?.toDouble(),
      );
}

/// İşçi (həkim, bərbər, usta) profili.
class StaffMember {
  const StaffMember({
    required this.id,
    required this.businessId,
    this.fullName,
    this.title,
    this.department,
    this.status = 'active',
  });

  final String id;
  final String businessId;
  final String? fullName;
  final String? title;
  final String? department;
  final String status;

  /// Siyahıda göstəriləcək ad — heç nə yoxdursa ID-nin qısası.
  String get displayName {
    if (fullName != null && fullName!.isNotEmpty) return fullName!;
    if (title != null && title!.isNotEmpty) return title!;
    return id.length > 8 ? id.substring(0, 8) : id;
  }

  factory StaffMember.fromJson(Map<String, dynamic> json) => StaffMember(
        id: json['id'] as String,
        businessId: json['business_id'] as String? ?? '',
        fullName: json['full_name'] as String?,
        title: json['title'] as String?,
        department: json['department'] as String?,
        status: json['status'] as String? ?? 'active',
      );
}

/// Xidmət kataloqu elementi — randevunun uzunluğunu təyin edir.
class ServiceItem {
  const ServiceItem({
    required this.id,
    required this.name,
    required this.durationMinutes,
    required this.price,
  });

  final String id;
  final String name;
  final int durationMinutes;
  final double price;

  factory ServiceItem.fromJson(Map<String, dynamic> json) => ServiceItem(
        id: json['id'] as String,
        name: json['name'] as String? ?? '',
        durationMinutes: (json['duration_minutes'] as num?)?.toInt() ?? 0,
        price: (json['price'] as num?)?.toDouble() ?? 0,
      );
}

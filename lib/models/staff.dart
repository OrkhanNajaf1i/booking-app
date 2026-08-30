/// Biznes (xəstəxana, klinika, bərbərxana, usta).
class BusinessCard {
  const BusinessCard({
    required this.id,
    required this.name,
    this.industry = '',
    this.serviceCategory = '',
    this.phone = '',
    this.businessType = '',
  });

  final String id;
  final String name;
  final String industry;
  final String serviceCategory;
  final String phone;
  final String businessType;

  /// Kartın altında göstərilən sahə etiketi.
  String get subtitle {
    if (serviceCategory.isNotEmpty) return serviceCategory;
    if (industry.isNotEmpty) return industry;
    return '';
  }

  factory BusinessCard.fromJson(Map<String, dynamic> json) => BusinessCard(
        id: json['id'] as String,
        name: json['name'] as String? ?? '',
        industry: json['industry'] as String? ?? '',
        serviceCategory: json['service_category'] as String? ?? '',
        phone: json['phone'] as String? ?? '',
        businessType: json['business_type'] as String? ?? '',
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

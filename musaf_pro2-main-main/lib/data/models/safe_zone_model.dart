import '../../domain/entities/safe_zone.dart';

/// [SafeZoneModel] هو امتداد للـ Entity الأساسية.
/// الهدف منه هو عزل تفاصيل قاعدة البيانات (مثل أسماء الحقول في Firebase) عن بقية التطبيق.
class SafeZoneModel extends SafeZone {
  SafeZoneModel({
    required super.id,
    required super.name,
    required super.latitude,
    required super.longitude,
    required super.radius,
    super.isActive,
  });

  factory SafeZoneModel.fromMap(Map<String, dynamic> map, String docId) {
    return SafeZoneModel(
      id: docId,
      name: map['name'] ?? '',
      // استخدام الأسماء الموحدة للزون الثابتة
      latitude: (map['latitude'] as num? ?? 0.0).toDouble(),
      longitude: (map['longitude'] as num? ?? 0.0).toDouble(),
      radius: (map['radius'] as num? ?? 0.0).toDouble(),
      isActive: map['isActive'] ?? true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'latitude': latitude,
      'longitude': longitude,
      'radius': radius,
      'isActive': isActive,
    };
  }
}
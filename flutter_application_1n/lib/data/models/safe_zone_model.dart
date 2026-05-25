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

  /// [factory] لتحويل البيانات القادمة من Firebase (Map) إلى كائن برمجى.
  /// تم توحيد أسماء الحقول لتطابق المسار المسطح المعتمد (last_latitude و last_longitude).
  /// استخدام [num] ثم [toDouble] يضمن عدم انهيار التطبيق إذا أرسل Firebase رقماً صحيحاً بدلاً من عشري.
  factory SafeZoneModel.fromMap(Map<String, dynamic> map, String docId) {
    return SafeZoneModel(
      id: docId,
      name: map['name'] ?? '',
      latitude: (map['last_latitude'] as num? ?? 0.0).toDouble(),
      longitude: (map['last_longitude'] as num? ?? 0.0).toDouble(),
      radius: (map['radius'] as num? ?? 0.0).toDouble(),
      isActive: map['isActive'] ?? true,
    );
  }

  /// تحويل الكائن إلى [Map] لتخزينه في Firestore.
  /// تم تعديل المفاتيح هنا لتتطابق تماماً مع الحقول المستخدمة في الـ Repository والـ Service.
  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'last_latitude': latitude,
      'last_longitude': longitude,
      'radius': radius,
      'isActive': isActive,
    };
  }
}
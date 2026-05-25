// lib/domain/entities/safe_zone.dart

class SafeZone {
  final String id;
  final String name;
  final double latitude;
  final double longitude;
  final double radius;
  final bool isActive; // تعديل الحقل ليصبح final لضمان عدم التغيير بالخطأ

  const SafeZone({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.radius,
    this.isActive = true,
  });

  /// [copyWith] هي الطريقة القياسية في المعمارية النظيفة لتعديل حقل معين
  /// دون الحاجة لتغيير الكائن الأصلي، حيث تقوم بإنشاء نسخة جديدة كلياً بالتعديلات المطلوبة.
  SafeZone copyWith({
    String? id,
    String? name,
    double? latitude,
    double? longitude,
    double? radius,
    bool? isActive,
  }) {
    return SafeZone(
      id: id ?? this.id,
      name: name ?? this.name,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      radius: radius ?? this.radius,
      isActive: isActive ?? this.isActive,
    );
  }
}
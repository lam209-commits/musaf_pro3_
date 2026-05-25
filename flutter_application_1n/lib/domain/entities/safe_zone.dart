// lib/domain/entities/safe_zone.dart
class SafeZone {
  final String id;
  final String name;
  final double latitude;
  final double longitude;
  final double radius;
bool isActive; 
  SafeZone({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.radius,
    this.isActive = true,
  });
}
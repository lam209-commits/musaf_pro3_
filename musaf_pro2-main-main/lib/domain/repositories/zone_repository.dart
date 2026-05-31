import '../entities/safe_zone.dart';

/// [ZoneRepository] هو العقد (Contract) الذي يحدد العمليات المطلوبة من طبقة البيانات.
abstract class ZoneRepository {
  
  Future<List<SafeZone>> getSafeZones(String patientId);
  Future<void> addSafeZone(String patientId, SafeZone zone);
  Future<void> deleteSafeZone(String patientId, String zoneId);
  Future<void> updateZoneStatus(String patientId, String zoneId, bool isActive);

Stream<List<Map<String, dynamic>>> getPatientAlertsStream(String patientId);
Future<void> markAlertAsRead(String patientId, String alertId);
Future<void> deleteAllAlerts(String patientId);
Future<void> deleteSingleAlert(String patientId, String alertId);
  Future<String> getPatientName(String patientId);

  Future<void> updatePatientStatus({
    required String patientId,
    required double latitude,
    required double longitude,
    required int batteryLevel,
    required bool isSafe,
    required String statusText,
  });
  

  // --- إدارة التنبيهات الذكية ---

  Future<void> sendAlert(String patientId, String message);
  
  
}
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:musaf_pro/data/models/safe_zone_model.dart';

class DatabaseService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // --- 1. إدارة المناطق الآمنة (Safe Zones) ---

  Future<List<SafeZoneModel>> getSafeZones(String patientId) async {
    try {
      var snapshot = await _db
          .collection('patients')
          .doc(patientId)
          .collection('safe_zones')
          .get();

      return snapshot.docs.map((doc) {
        return SafeZoneModel.fromMap(doc.data(), doc.id);
      }).toList();
    } catch (e) {
      print("❌ Error fetching zones: $e");
      return [];
    }
  }

  Future<void> addSafeZone(String patientId, SafeZoneModel zone) async {
    try {
      await _db
          .collection('patients')
          .doc(patientId)
          .collection('safe_zones')
          .add(zone.toMap());
    } catch (e) {
      print("❌ Error adding zone: $e");
    }
  }

  // --- 2. إدارة التنبيهات (Alerts) ---

  // جلب التنبيهات لحظياً
  Stream<QuerySnapshot> getPatientAlerts(String patientId) {
    return _db
        .collection('patients')
        .doc(patientId)
        .collection('alerts')
        .orderBy('timestamp', descending: true)
        .snapshots();
  }

  // إرسال تنبيه جديد
  Future<void> sendExitAlert(String patientId, String zoneName) async {
    try {
      await _db.collection('patients').doc(patientId).collection('alerts').add({
        'type': 'exit',
        'title': 'تنبيه خروج',
        'message': '⚠️ خرج المريض من منطقة: $zoneName',
        'is_read': false,
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print("❌ Error sending alert: $e");
    }
  }

  // تحديث حالة التنبيه ليكون مقروءاً
  Future<void> markAlertAsRead(String alertId, String patientId) async {
    try {
      await _db
          .collection('patients')
          .doc(patientId)
          .collection('alerts')
          .doc(alertId)
          .update({'is_read': true});
    } catch (e) {
      print("❌ Error marking alert as read: $e");
    }
  }

  // حذف تنبيه واحد
  Future<void> deleteAlert(String alertId, String patientId) async {
    try {
      await _db
          .collection('patients')
          .doc(patientId)
          .collection('alerts')
          .doc(alertId)
          .delete();
    } catch (e) {
      print("❌ Error deleting alert: $e");
    }
  }

  // حذف جميع التنبيهات
  Future<void> deleteAllAlerts(String patientId) async {
    try {
      var collection = _db.collection('patients').doc(patientId).collection('alerts');
      var snapshots = await collection.get();
      
      final batch = _db.batch();
      for (var doc in snapshots.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
      print("✅ All alerts deleted");
    } catch (e) {
      print("❌ Error deleting all alerts: $e");
    }
  }

  // --- 3. إدارة الموقع (Tracking) ---

  Future<void> updatePatientLocation({
    required String patientId,
    required double lat,
    required double lng,
    required int battery,
  }) async {
    try {
      // تم تعديل أسماء الحقول لتطابق (last_latitude و last_longitude و battery_level) لتوحيدها مع المستودع
      await _db.collection('patients').doc(patientId).set({
        'last_latitude': lat,
        'last_longitude': lng,
        'battery_level': battery,
        'last_update': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      print("❌ Error updating location: $e");
    }
  }
}
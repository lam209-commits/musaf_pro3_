import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/entities/safe_zone.dart';
import '../../domain/repositories/zone_repository.dart';
import '../models/safe_zone_model.dart';

class FirebaseZoneRepository implements ZoneRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // توحيد المسار المسطح والمباشر للمناطق الآمنة تحت مجموعة patients لإنهاء التضارب
  CollectionReference _getZoneCollection(String patientId) {
    return _firestore
        .collection('patients')
        .doc(patientId)
        .collection('safe_zones');
  }

  @override
  Future<List<SafeZone>> getSafeZones(String patientId) async {
    try {
      final snapshot = await _getZoneCollection(patientId).get();
      return snapshot.docs.map((doc) {
        return SafeZoneModel.fromMap(
          doc.data() as Map<String, dynamic>, 
          doc.id,
        );
      }).toList();
    } catch (e) {
      throw Exception("فشل في جلب المناطق الآمنة: $e");
    }
  }

  @override
  Future<void> addSafeZone(String patientId, SafeZone zone) async {
    try {
      final model = SafeZoneModel(
        id: '', 
        name: zone.name,
        latitude: zone.latitude,
        longitude: zone.longitude,
        radius: zone.radius,
        isActive: zone.isActive,
      );
      await _getZoneCollection(patientId).add(model.toMap());
    } catch (e) {
      throw Exception("فشل في إضافة المنطقة: $e");
    }
  }

  @override
  Future<void> deleteSafeZone(String patientId, String zoneId) async {
    try {
      await _getZoneCollection(patientId).doc(zoneId).delete();
    } catch (e) {
      throw Exception("فشل في حذف المنطقة: $e");
    }
  }

  @override
  Future<void> updateZoneStatus(String patientId, String zoneId, bool isActive) async {
    try {
      await _getZoneCollection(patientId).doc(zoneId).update({'isActive': isActive});
    } catch (e) {
      throw Exception("فشل في تحديث حالة المنطقة: $e");
    }
  }

  @override
  Future<String> getPatientName(String patientId) async {
    try {
      // تعديل المسار هنا ليكون متوافقاً مع المجموعات الموحدة
      var doc = await _firestore.collection('patients').doc(patientId).get();
      if (doc.exists) {
        return doc.data()?['name'] ?? "المريض";
      }
      return "مريض غير معروف";
    } catch (e) {
      return "المريض";
    }
  }

  @override
  Future<void> updatePatientStatus({
    required String patientId,
    required double latitude,
    required double longitude,
    required int batteryLevel,
    required bool isSafe,
    required String statusText,
  }) async {
    try {
      await _firestore.collection('patients').doc(patientId).set({
        'last_latitude': latitude,
        'last_longitude': longitude,
        'battery_level': batteryLevel,
        'is_safe': isSafe,
        'last_update': FieldValue.serverTimestamp(),
        'status': statusText,
      }, SetOptions(merge: true));
    } catch (e) {
      print("Error updating patient status: $e");
    }
  }

  @override
  Future<void> sendAlert(String patientId, String message) async {
    try {
      await _firestore
          .collection('patients')
          .doc(patientId)
          .collection('alerts')
          .add({
        'message': message,
        'timestamp': FieldValue.serverTimestamp(),
        'is_read': false,
        'type': message.contains("خرج") ? 'exit' : (message.contains("بطارية") ? 'battery' : 'general'),
      });
    } catch (e) {
      print("Error sending alert: $e");
    }
  }

  @override
  Stream<List<Map<String, dynamic>>> getPatientAlertsStream(String patientId) {
    return _firestore
        .collection('patients')
        .doc(patientId)
        .collection('alerts')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) {
              final data = doc.data();
              final timestamp = data['timestamp'] as Timestamp?;
              return {
                ...data,
                'id': doc.id,
                'time_string': timestamp != null 
                    ? "${timestamp.toDate().hour}:${timestamp.toDate().minute.toString().padLeft(2, '0')}" 
                    : "",
              };
            }).toList());
  }

  @override
  Future<void> markAlertAsRead(String patientId, String alertId) async {
    try {
      await _firestore
          .collection('patients')
          .doc(patientId)
          .collection('alerts')
          .doc(alertId)
          .update({'is_read': true});
    } catch (e) {
      print("Error marking alert as read: $e");
    }
  }

  @override
  Future<void> deleteSingleAlert(String patientId, String alertId) async {
    try {
      await _firestore
          .collection('patients')
          .doc(patientId)
          .collection('alerts')
          .doc(alertId)
          .delete();
    } catch (e) {
      print("Error deleting alert: $e");
    }
  }

  @override
  Future<void> deleteAllAlerts(String patientId) async {
    try {
      final batch = _firestore.batch();
      final collection = _firestore.collection('patients').doc(patientId).collection('alerts');
      final snapshots = await collection.get();
      
      for (var doc in snapshots.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    } catch (e) {
      print("Error deleting all alerts: $e");
    }
  }
}
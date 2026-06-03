import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/entities/safe_zone.dart';
import '../../domain/repositories/zone_repository.dart';
import '../models/safe_zone_model.dart';

class FirebaseZoneRepository implements ZoneRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference _zones(String patientId) =>
      _firestore.collection('patients').doc(patientId).collection('safe_zones');

  // =========================
  // SAFE ZONES
  // =========================
  @override
  Future<List<SafeZone>> getSafeZones(String patientId) async {
    final snapshot = await _zones(patientId).get();

    return snapshot.docs.map((doc) {
      return SafeZoneModel.fromMap(
        doc.data() as Map<String, dynamic>,
        doc.id,
      );
    }).toList();
  }

  @override
  Future<void> addSafeZone(String patientId, SafeZone zone) async {
    final model = SafeZoneModel(
      id: '',
      name: zone.name,
      latitude: zone.latitude,
      longitude: zone.longitude,
      radius: zone.radius,
      isActive: zone.isActive,
    );

    await _zones(patientId).add(model.toMap());
  }

  @override
  Future<void> deleteSafeZone(String patientId, String zoneId) async {
    await _zones(patientId).doc(zoneId).delete();
  }

  // =========================
  // REAL-TIME PATIENT STATUS (FIXED)
  // =========================
  @override
  Future<void> updatePatientStatus({
    required String patientId,
    required double latitude,
    required double longitude,
    required int batteryLevel,
    required bool isSafe,
    required String statusText,
  }) async {
    await _firestore.collection('patients').doc(patientId).set({
      'last_latitude': latitude,
      'last_longitude': longitude,
      'battery_level': batteryLevel,
      'is_safe': isSafe,
      'status': statusText,
      'lastSeen': FieldValue.serverTimestamp(),
      'signalStatus': 'online',
    }, SetOptions(merge: true));
  }

  // =========================
  // ALERT SYSTEM (STRUCTURED)
  // =========================
  @override
  Future<void> sendAlert(String patientId, String message) async {
    String type = 'general';
    String title = 'تنبيه';

    if (message.contains("خرج")) {
      type = 'exit';
      title = 'خروج من المنطقة';
    } else if (message.contains("عاد")) {
      type = 'entry';
      title = 'عودة للمنطقة';
    } else if (message.contains("بطارية")) {
      type = 'battery';
      title = 'بطارية منخفضة';
    } else if (message.contains("الاتصال")) {
      type = 'signal_loss';
      title = 'انقطاع اتصال';
    }

    await _firestore
        .collection('patients')
        .doc(patientId)
        .collection('alerts')
        .add({
      'title': title,
      'message': message,
      'type': type,
      'is_read': false,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  // =========================
  // STREAM ALERTS
  // =========================
  @override
  Stream<List<Map<String, dynamic>>> getPatientAlertsStream(String patientId) {
    return _firestore
        .collection('patients')
        .doc(patientId)
        .collection('alerts')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          ...data,
          'id': doc.id,
        };
      }).toList();
    });
  }

  @override
  Future<void> markAlertAsRead(String patientId, String alertId) async {
    await _firestore
        .collection('patients')
        .doc(patientId)
        .collection('alerts')
        .doc(alertId)
        .update({'is_read': true});
  }

  @override
  Future<void> deleteSingleAlert(String patientId, String alertId) async {
    await _firestore
        .collection('patients')
        .doc(patientId)
        .collection('alerts')
        .doc(alertId)
        .delete();
  }

  @override
  Future<void> deleteAllAlerts(String patientId) async {
    final batch = _firestore.batch();
    final snapshot = await _firestore
        .collection('patients')
        .doc(patientId)
        .collection('alerts')
        .get();

    for (final doc in snapshot.docs) {
      batch.delete(doc.reference);
    }

    await batch.commit();
  }
  
 @override
  Future<String> getPatientName(String patientId) async {
    try {
      final doc = await _firestore.collection('users').doc(patientId).get();
      
      if (doc.exists) {
        // نجلب حقل displayName وإذا لم يكن موجوداً نرجع قيمة افتراضية
        return doc.data()?['displayName'] ?? 'التابع غير معروف';
      }
      return 'التابع غير معروف';
    } catch (e) {
      print("Error getting patient name: $e");
      return 'التابع غير معروف';
    }
  }
  
  @override
 @override
  Future<void> updateZoneStatus(String patientId, String zoneId, bool isActive) async {
    try {
      await _firestore
          .collection('patients')
          .doc(patientId)
          .collection('safe_zones')
          .doc(zoneId)
          .update({'isActive': isActive});
    } catch (e) {
      print("Error updating zone status: $e");
    }
  }
}
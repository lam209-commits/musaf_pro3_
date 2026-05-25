
import 'package:cloud_firestore/cloud_firestore.dart';
class FirebaseHelper {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Stream<QuerySnapshot> getZonesStream(String patientId) {
    return _db.collection('patients').doc(patientId).collection('safe_zones').snapshots();
  }

  Future<void> addZone(String patientId, Map<String, dynamic> data) async {
    await _db.collection('patients').doc(patientId).collection('safe_zones').add(data);
  }
}
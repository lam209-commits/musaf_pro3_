import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/entities/user_entity.dart';
import '../../domain/repositories/auth_repository.dart';
import '../models/user_model.dart';

class FirebaseAuthRepositoryImpl implements AuthRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  Future<UserEntity?> findPatientByCaregiverEmail(String email) async {
    try {
      // البحث عن المريض الذي يحتوي حسابه على إيميل هذا المرافق
      var querySnapshot = await _firestore
          .collection('users')
          .where('caregiverEmail', isEqualTo: email)
          .where('role', isEqualTo: 'patient') // تأكيد أن المستهدف مريض وليس مرافق آخر
          .get(const GetOptions(source: Source.server));

      if (querySnapshot.docs.isEmpty) return null;
      return UserModel.fromFirestore(querySnapshot.docs.first);
    } catch (e) {
      throw Exception("فشل في العثور على المريض عبر البريد: $e");
    }
  }

  @override
  Future<void> saveUserData(UserEntity user) async {
    try {
      final userModel = UserModel(
        uid: user.uid,
        displayName: user.displayName,
        phoneNumber: user.phoneNumber,
        role: user.role,
        email: user.email,
        caregiverEmail: user.caregiverEmail,
        relation: user.relation,
        pairingCode: user.pairingCode,
        isCaregiverVerified: user.isCaregiverVerified,
        linkedPatientId: user.linkedPatientId,
        linkedPatientName: user.linkedPatientName,
      );
      
      // حفظ البيانات باستخدام toFirestore الموحدة التي قمت بكتابتها
      await _firestore
          .collection('users')
          .doc(user.uid)
          .set(userModel.toFirestore(), SetOptions(merge: true)); // استخدام merge منعاً لمسح أي حقول فرعية بالخطأ
    } catch (e) {
      throw Exception("فشل في حفظ بيانات المستخدم: $e");
    }
  }

  @override
  Future<UserEntity?> getUserData(String uid) async {
    try {
      var docSnapshot = await _firestore
          .collection('users')
          .doc(uid)
          .get(); // ترك الخيار التلقائي (Server/Cache) لضمان عمل التطبيق حتى عند تذبذب شبكة الإسعاف

      if (!docSnapshot.exists || docSnapshot.data() == null) return null;
      return UserModel.fromFirestore(docSnapshot);
    } catch (e) {
      throw Exception("فشل في جلب بيانات المستخدم: $e");
    }
  }

  /// 💡 دالة إضافية هامة جداً لمشروعك (تأكد من إضافتها للـ Interface في الـ Domain layer أولاً إذا أردت استخدامها)
  /// تستخدم لربط المرافق بالمريض عن طريق كود الاقتران اللحظي (Pairing Code)
  Future<bool> linkCaregiverWithPatient({
    required String caregiverId,
    required String caregiverName,
    required String pairingCode,
  }) async {
    try {
      // 1. البحث عن المريض صاحب هذا الكود
      var patientQuery = await _firestore
          .collection('users')
          .where('pairingCode', isEqualTo: pairingCode)
          .where('role', isEqualTo: 'patient')
          .get();

      if (patientQuery.docs.isEmpty) return false;

      var patientDoc = patientQuery.docs.first;
      String patientId = patientDoc.id;
      String patientName = patientDoc.data()['displayName'] ?? 'مريض';

      final batch = _firestore.batch();

      // 2. تحديث بيانات المرافق ليصبح مرتبكاً بهذا المريض
      var caregiverRef = _firestore.collection('users').doc(caregiverId);
      batch.update(caregiverRef, {
        'linkedPatientId': patientId,
        'linkedPatientName': patientName,
        'isCaregiverVerified': true,
      });

      // 3. تحديث بيانات المريض لتوثيق الربط
      var patientRef = _firestore.collection('users').doc(patientId);
      batch.update(patientRef, {
        'isCaregiverVerified': true,
        // يمكنك مسح كود الاقتران هنا بعد استخدامه لمرة واحدة لزيادة الأمان
        'pairingCode': FieldValue.delete(), 
      });

      await batch.commit();
      return true;
    } catch (e) {
      print("Error during pairing process: $e");
      return false;
    }
  }
}
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/entities/user_entity.dart';

class UserModel extends UserEntity {
  const UserModel({
    required super.uid,
    required super.displayName,
    required super.phoneNumber,
    required super.role,
    required super.email,
    super.caregiverEmail, // 👈 جعلناها اختيارية (بدون required) لتناسب الجميع
    super.relation,       // 👈 أضفناها هنا
    super.linkedPatientId,
    super.linkedPatientName,
    super.caregiverId,
    super.caregiverName,
    super.pairingCode,

    super.patientVerificationCode, // 🚀 👈 تمريره للـ super
    super.isLinked = false, // قيمة افتراضية
    super.isEmailVerified, 
  });

  // تحويل البيانات من Firestore إلى Model
  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};

    return UserModel(
      uid: doc.id,
      displayName: data['displayName'] ?? '',
      phoneNumber: data['phoneNumber'] ?? '',
      role: data['role'] ?? 'patient',
      email: data['email'] ?? '',
      caregiverEmail: data['caregiverEmail'], // قراءة الإيميل
      relation: data['relation'],             // قراءة العلاقة
      linkedPatientId: data['linkedPatientId'],
      linkedPatientName: data['linkedPatientName'],
      caregiverId: data['caregiverId'],
      caregiverName: data['caregiverName'],
      pairingCode: data['pairingCode'],
      patientVerificationCode: data['patientVerificationCode'], // 🚀 👈 قراءة الكود من فايربيز
      isLinked: data['isLinked'] ?? false,
      isEmailVerified: data['isEmailVerified'], 
    );
  }

  // تحويل البيانات من Model إلى Firestore
  Map<String, dynamic> toFirestore() {
    return {
      'uid': uid,
      'displayName': displayName,
      'phoneNumber': phoneNumber,
      'role': role,
      'email': email,
      'caregiverEmail': caregiverEmail,
      'relation': relation,
      'isLinked': isLinked,
      'updatedAt': FieldValue.serverTimestamp(),
      
      // الحقول الاختيارية (باستخدام if)
      if (linkedPatientId != null) 'linkedPatientId': linkedPatientId,
      if (linkedPatientName != null) 'linkedPatientName': linkedPatientName,
      if (caregiverId != null) 'caregiverId': caregiverId,
      if (caregiverName != null) 'caregiverName': caregiverName,
      if (pairingCode != null) 'pairingCode': pairingCode,
      if (patientVerificationCode != null) 'patientVerificationCode': patientVerificationCode, // 🚀 👈 حفظ الكود في فايربيز
      if (isEmailVerified != null) 'isEmailVerified': isEmailVerified,
    };
  }
}
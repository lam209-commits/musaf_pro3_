import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/entities/user_entity.dart';

class UserModel extends UserEntity {
  const UserModel({
    required super.uid,
    required super.displayName,
    required super.phoneNumber,
    required super.role,
    required super.email,
    super.patientVerificationCode, // 👈 تمت الإضافة هنا لكي لا يظهر لك خطأ
    super.isEmailVerified,
    super.caregiverEmail,
    super.relation,
    super.pairingCode,
    super.isCaregiverVerified,
    super.linkedPatientId,
    super.linkedPatientName,
  });

  // تحويل البيانات القادمة من Firestore إلى موديل برمجى
  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return UserModel(
      uid: doc.id,
      displayName: data['displayName'] ?? '',
      phoneNumber: data['phoneNumber'] ?? '',
      role: data['role'] ?? 'patient',
      email: data['email'] ?? '',
      patientVerificationCode: data['patientVerificationCode'],
      isEmailVerified: data['isEmailVerified'],
      caregiverEmail: data['caregiverEmail'],
      relation: data['relation'],
      pairingCode: data['pairingCode'],
      isCaregiverVerified: data['isCaregiverVerified'],
      linkedPatientId: data['linkedPatientId'],
      linkedPatientName: data['linkedPatientName'],
    );
  }

  // تحويل الكائن إلى Map لرفعه وحفظه في Firestore
  Map<String, dynamic> toFirestore() {
    return {
      'uid': uid,
      'displayName': displayName,
      'phoneNumber': phoneNumber,
      'role': role,
      'email': email,
      'patientVerificationCode': patientVerificationCode,
      'isEmailVerified': isEmailVerified,
      if (patientVerificationCode != null) 'patientVerificationCode': patientVerificationCode,
      if (isEmailVerified != null) 'isEmailVerified': isEmailVerified,
      if (caregiverEmail != null) 'caregiverEmail': caregiverEmail,
      if (relation != null) 'relation': relation,
      if (pairingCode != null) 'pairingCode': pairingCode,
      if (isCaregiverVerified != null) 'isCaregiverVerified': isCaregiverVerified,
      if (linkedPatientId != null) 'linkedPatientId': linkedPatientId,
      if (linkedPatientName != null) 'linkedPatientName': linkedPatientName,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }
}
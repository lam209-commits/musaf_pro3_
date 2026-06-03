class UserEntity {
  final String uid;
  final String displayName;
  final String phoneNumber;
  final String role; // patient | caregiver
  final String email;
  final String? relation;
  final String? caregiverEmail; // 👈 أضيفي هذا السطر هنا

  // ====== ربط المرافق بالمريض ======
  final String? linkedPatientId;
  final String? linkedPatientName;

  // ====== ربط المريض بالمرافق (مهم جداً) ======
  final String? caregiverId;
  final String? caregiverName;

  // ====== نظام التحقق ======
  final String? pairingCode;
  final String? patientVerificationCode; // 🚀 👈 الحقل الذي كان مفقوداً ويسبب المشكلة
  final bool isLinked;

  // ====== إضافات تحقق ======
  final bool? isEmailVerified;

  const UserEntity({
    required this.uid,
    required this.displayName,
    required this.phoneNumber,
    required this.role,
    required this.email,

    this.linkedPatientId,
    this.linkedPatientName,

    this.caregiverId,
    this.caregiverName,

    this.pairingCode,
    this.isLinked = false,

    this.isEmailVerified, this.relation, this.caregiverEmail, this.patientVerificationCode,
  });

  bool get isCaregiverVerified => isLinked;
}
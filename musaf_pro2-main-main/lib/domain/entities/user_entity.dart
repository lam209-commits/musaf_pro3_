class UserEntity {
  final String uid;
  final String displayName;
  final String phoneNumber;
  final String role;
  final String email;
  final String? caregiverEmail;
  final String? relation;
  final String? pairingCode;
  final bool? isCaregiverVerified;
  final String? linkedPatientId;
  final String? linkedPatientName;

  const UserEntity({
    required this.uid,
    required this.displayName,
    required this.phoneNumber,
    required this.role,
    required this.email,
    this.caregiverEmail,
    this.relation,
    this.pairingCode,
    this.isCaregiverVerified,
    this.linkedPatientId,
    this.linkedPatientName,
  });
}
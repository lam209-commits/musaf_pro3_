import '../entities/user_entity.dart';

abstract class AuthRepository {
  // البحث الفوري عن المريض بواسطة بريد المرافق في السيرفر
  Future<UserEntity?> findPatientByCaregiverEmail(String email);
  
  // حفظ مستند المستخدم بالكامل داخل الفايربيس (مع استخدام merge في الـ Impl لحماية الحقول)
  Future<void> saveUserData(UserEntity user);

  // جلب بيانات المستخدم بناءً على الـ UID الخاص به
  Future<UserEntity?> getUserData(String uid);

  /// 💡 الإضافة الهامة: عقد عملية ربط المرافق بالمريض برمجياً
  Future<bool> linkCaregiverWithPatient({
    required String caregiverId,
    required String caregiverName,
    required String pairingCode,
  });
  Future<void> unlinkPatientLogic(String currentUserId, String patientId);
  
  // 2. حذف الحساب بأمان
  Future<void> deleteUserAccountSecurely(String currentPassword);
  
  // 3. رفع الصورة
  Future<void> uploadProfileImage(String currentUserId, String imagePath);
}
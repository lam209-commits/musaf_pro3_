import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:musaf_pro/data/models/user_model.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // 1. دالة تسجيل الدخول المستقرة
 // 1. دالة تسجيل الدخول المستقرة (معدلة لإرسال تفاصيل الخطأ للواجهة)
  Future<User?> signIn(String email, String password) async {
    try {
      UserCredential result = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return result.user;
    } on FirebaseAuthException catch (e) {
      // 🚀 هنا نرمي الخطأ الدقيق للواجهة لكي تقوم بتحليله وعرض الرسالة المناسبة
      throw e; 
    } catch (e) {
      throw Exception('حدث خطأ غير متوقع');
    }
  }

  // 2. دالة تسجيل مستخدم جديد (معدلة ومطابقة لـ UserModel و Repositories الموحدة)
  Future<User?> registerUser({
    required String email,
    required String password,
    required String displayName,
    required String phoneNumber,
    required String role, // مريض (patient) أو مرافق (caregiver)
  }) async {
    try {
      UserCredential result = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      User? user = result.user;

      if (user != null) {
        // توليد كود الربط المكون من 6 أرقام
        String pCode = (Random().nextInt(900000) + 100000).toString();

        // بناء كائن الـ Model المتوافق هندسياً مع الكور لتجنب تضارب الحقول 
        final userModel = UserModel(
          uid: user.uid,
          displayName: displayName,
          phoneNumber: phoneNumber,
          role: role,
          email: email,
          pairingCode: role == 'patient' ? pCode : null, // الكود يُمنح للمريض فقط ليقترن به المرافق
        );

        await _firestore
            .collection('users')
            .doc(user.uid)
            .set(userModel.toFirestore());
      }
      return user;
    } catch (e) {
      debugPrint("خطأ في التسجيل: ${e.toString()}");
      return null;
    }
  }

  // دالة تسجيل الخروج
  Future<void> signOut() async {
    await _auth.signOut();
  }
  // أضف هذه الدالة داخل كلاس AuthService
Future<void> deleteAccount() async {
  User? user = _auth.currentUser;
  
  if (user != null) {
    try {
      // 1. حذف مستند المستخدم من Firestore
      await _firestore.collection('users').doc(user.uid).delete();
      
      // 2. حذف الحساب من Firebase Authentication
      await user.delete();
      
      debugPrint("✅ تم حذف الحساب والبيانات بنجاح");
    } on FirebaseAuthException catch (e) {
      if (e.code == 'requires-recent-login') {
        // هذا الخطأ يعني أن المستخدم يجب أن يسجل خروجه ويدخل مجدداً لأسباب أمنية
        throw Exception('يرجى تسجيل الخروج والدخول مجدداً لحذف الحساب');
      }
      throw e;
    } catch (e) {
      throw Exception('تعذر حذف الحساب: $e');
    }
  }
}
}
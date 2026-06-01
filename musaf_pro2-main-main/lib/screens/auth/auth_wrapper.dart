import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:musaf_pro/domain/repositories/auth_repository.dart';
import 'package:musaf_pro/screens/auth/PermissionHandle.dart';
import 'package:musaf_pro/screens/auth/login_screen.dart';
import 'package:musaf_pro/screens/auth/pairing_code_screen.dart';
import 'package:musaf_pro/screens/home_screen.dart';
import 'package:musaf_pro/screens/patient_home_screen.dart';
import 'package:musaf_pro/screens/patient_verification_screen.dart';

import '../../domain/entities/user_entity.dart'; 
import '../../data/repositories/firebase_auth_repository_impl.dart';

// استيراد الشاشات

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});
@override
  Widget build(BuildContext context) {
    final AuthRepository authRepository = FirebaseAuthRepositoryImpl();
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // 1. أثناء انتظار جلب حالة تسجيل الدخول من فايربيز
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        // 2. إذا كان هناك مستخدم مسجل دخول بالفعل
        if (snapshot.hasData && snapshot.data != null) {
          return FutureBuilder<UserEntity?>(
            // نفترض هنا أنك تستدعين الدالة التي تجلب بيانات المستخدم
future: authRepository.getUserData(snapshot.data!.uid),            builder: (context, userSnapshot) {
              if (userSnapshot.connectionState == ConnectionState.waiting) {
                return const Scaffold(body: Center(child: CircularProgressIndicator()));
              }

              final userEntity = userSnapshot.data;

              // إذا لم نجد بيانات للمستخدم في قاعدة البيانات
              if (userEntity == null) return const LoginScreen();

              // 🛑 منطق التحقق الجذري (حارس البوابة)
              if (userEntity.role == 'caregiver') {
                // التحقق هل المرافق مرتبط بمريض؟
                final bool isLinked = userEntity.linkedPatientId != null && 
                                      userEntity.linkedPatientId!.isNotEmpty;
                
                return isLinked 
                    ? const PermissionHandlerWrapper(userType: 'caregiver') 
                    : const PairingCodeScreen();
              } else {
                // 🚀 التحقق من إيميل المريض قبل إدخاله!
                if (userEntity.isEmailVerified == false) {
                  return const PatientVerificationScreen();
                } else {
                  return const PermissionHandlerWrapper(userType: 'patient');
                }
              }
            },
          ); // 👈 إغلاق الـ FutureBuilder الخاص بجلب بيانات المستخدم
        } 
        
        // 3. إذا لم يكن هناك مستخدم مسجل دخول من الأساس (مكانها الصحيح هنا)
        return const LoginScreen();
      }, // 👈 إغلاق الـ StreamBuilder الخاص بفايربيز
    );
  }
} // 👈 إغلاق الكلاس
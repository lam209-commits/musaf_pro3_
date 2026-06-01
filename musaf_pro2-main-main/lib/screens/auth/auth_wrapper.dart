import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:musaf_pro/screens/auth/login_screen.dart';
import 'package:musaf_pro/screens/auth/pairing_code_screen.dart';
import 'package:musaf_pro/screens/home_screen.dart';
import 'package:musaf_pro/screens/patient_home_screen.dart';

import '../../domain/entities/user_entity.dart'; 
import '../../data/repositories/firebase_auth_repository_impl.dart';

// استيراد الشاشات

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // 1. حالة التحميل أثناء التأكد من وجود جلسة دخول
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        
        // 2. إذا كان المستخدم مسجلاً دخوله
        if (snapshot.hasData) {
          return FutureBuilder<UserEntity?>(
            future: FirebaseAuthRepositoryImpl().getUserData(snapshot.data!.uid),
            builder: (context, userSnapshot) {
              // حالة التحميل أثناء جلب بيانات المستخدم من Firestore
              if (userSnapshot.connectionState == ConnectionState.waiting) {
                return const Scaffold(
                  body: Center(child: CircularProgressIndicator()),
                );
              }
              
              final userEntity = userSnapshot.data;
              
              // إذا لم نجد بيانات للمستخدم، نخرجه لشاشة تسجيل الدخول
              if (userEntity == null) return const LoginScreen();

              // 🛑 منطق التحقق الجذري (حارس البوابة)
              if (userEntity.role == 'caregiver') {
                // التحقق هل المرافق مرتبط بمريض؟
                final bool isLinked = userEntity.linkedPatientId != null && 
                                     userEntity.linkedPatientId!.isNotEmpty;
                
                // إذا كان مرتبطاً يذهب للهوم، وإذا لا يذهب لشاشة الربط
                return isLinked ? const HomeScreen() : const PairingCodeScreen();
              } else {
                // إذا كان مريضاً، يذهب لشاشة المريض مباشرة
                return const PatientHomeScreen();
              }
            },
          );
        }
        
        // 3. إذا لم يكن هناك مستخدم مسجل دخول
        return const LoginScreen();
      },
    );
  }
}
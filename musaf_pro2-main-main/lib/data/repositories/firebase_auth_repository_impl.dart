import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../../domain/entities/user_entity.dart';
import '../../domain/repositories/auth_repository.dart';
import '../models/user_model.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

class FirebaseAuthRepositoryImpl implements AuthRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // =========================
  // USER SAVE
  // =========================
  
@override
Future<void> saveUserData(UserEntity user) async {
  final model = UserModel(
    uid: user.uid,
    displayName: user.displayName,
    phoneNumber: user.phoneNumber,
    role: user.role,
    email: user.email,

    caregiverEmail: user.caregiverEmail,
    relation: user.relation,

    linkedPatientId: user.linkedPatientId,
    linkedPatientName: user.linkedPatientName,

    caregiverId: user.caregiverId,
    caregiverName: user.caregiverName,

    pairingCode: user.pairingCode,

    patientVerificationCode:
        user.patientVerificationCode,

    isLinked: user.isLinked,

    isEmailVerified: user.isEmailVerified,
  );

  await _firestore
      .collection('users')
      .doc(user.uid)
      .set(
        model.toFirestore(),
        SetOptions(merge: true),
      );
}

  // =========================
  // GET USER
  // =========================
  @override
  Future<UserEntity?> getUserData(String uid) async {
    final doc = await _firestore.collection('users').doc(uid).get();
    if (!doc.exists) return null;
    return UserModel.fromFirestore(doc);
  }

  // =========================
  // LINK CAREGIVER <-> PATIENT
  // =========================
  @override
  Future<bool> linkCaregiverWithPatient({
    required String caregiverId,
    required String caregiverName,
    required String pairingCode,
  }) async {
    try {
      final patientQuery = await _firestore
          .collection('users')
          .where('pairingCode', isEqualTo: pairingCode)
          .where('role', isEqualTo: 'patient')
          .get();

      if (patientQuery.docs.isEmpty) return false;

      final patientDoc = patientQuery.docs.first;
      final patientId = patientDoc.id;
      final patientName = patientDoc['displayName'];

      final batch = _firestore.batch();

      final caregiverRef = _firestore.collection('users').doc(caregiverId);
      final patientRef = _firestore.collection('users').doc(patientId);

      // 🟢 caregiver update
      batch.update(caregiverRef, {
        'linkedPatientId': patientId,
        'linkedPatientName': patientName,
        'isLinked': true,
      });

      // 🟢 patient update (IMPORTANT FIX)
      batch.update(patientRef, {
        'caregiverId': caregiverId,
        'caregiverName': caregiverName,
        'isLinked': true,
        'pairingCode': FieldValue.delete(),
      });

      // 🟢 ENSURE patients collection exists (CRITICAL FIX)
      await _firestore.collection('patients').doc(patientId).set({
        'patientId': patientId,
        'caregiverId': caregiverId,
        'lastSeen': FieldValue.serverTimestamp(),
        'signalStatus': 'online',
      }, SetOptions(merge: true));

      await batch.commit();
      return true;
    } catch (e) {
      debugPrint("link error: $e");
      return false;
    }
  }

// استدعاء هذه الدالة بعد تسجيل دخول المرافق بنجاح
Future<void> saveCaregiverFCMToken(String caregiverId) async {
  String? fcmToken = await FirebaseMessaging.instance.getToken();
  
  if (fcmToken != null) {
    await FirebaseFirestore.instance
        .collection('users')
        .doc(caregiverId)
        .update({'fcmToken': fcmToken});
  }
}

  // =========================
  // UNLINK (FIXED)
  // =========================
  @override
  Future<void> unlinkPatientLogic(String userId, String patientId) async {
    final batch = _firestore.batch();

    batch.update(_firestore.collection('users').doc(userId), {
      'linkedPatientId': FieldValue.delete(),
      'linkedPatientName': FieldValue.delete(),
      'isLinked': false,
    });

    batch.update(_firestore.collection('users').doc(patientId), {
      'caregiverId': FieldValue.delete(),
      'caregiverName': FieldValue.delete(),
      'isLinked': false,
    });

    await batch.commit();
  }

  // =========================
  // DELETE USER (FIXED SAFETY)
  // =========================
 @override
  Future<void> deleteUserAccountSecurely(String password) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // 1. إعادة المصادقة (خطوة أمنية ضرورية)
    final credential = EmailAuthProvider.credential(
      email: user.email!,
      password: password,
    );
    await user.reauthenticateWithCredential(credential);

    // 2. جلب بيانات المستخدم لمعرفة إذا كان مرتبطاً بـ patientId
    final doc = await _firestore.collection('users').doc(user.uid).get();
    final data = doc.data();
    final linkedPatientId = data?['linkedPatientId'];

    // 3. فك الارتباط في مستند المريض (في مجموعة users)
    if (linkedPatientId != null) {
      await _firestore.collection('users').doc(linkedPatientId).update({
        'caregiverId': FieldValue.delete(),
        'caregiverName': FieldValue.delete(),
        'isLinked': false,
      });

      // 🛑 الإضافة الهامة: حذف مستند المريض من مجموعة patients الخاصة بالتتبع
      // لكي يتوقف تطبيق المريض عن إرسال التحديثات للمرافق المحذوف
      await _firestore.collection('patients').doc(linkedPatientId).delete();
    }

    // 4. حذف مستند المستخدم الحالي من الـ users
    await _firestore.collection('users').doc(user.uid).delete();
    
    // 5. حذف حساب المستخدم من Firebase Auth
    await user.delete();
  }

  // =========================
  // PROFILE IMAGE
  // =========================
  @override
  Future<void> uploadProfileImage(String uid, String path) async {
    final ref = FirebaseStorage.instance
        .ref()
        .child('profile_images')
        .child('$uid.jpg');

    await ref.putFile(File(path));

    final url = await ref.getDownloadURL();

    await _firestore.collection('users').doc(uid).update({
      'profileImageUrl': url,
    });
  }
  
  
  
@override
Future<UserEntity?> findPatientByCaregiverEmail(
    String email) async {
  try {
    final query = await _firestore
        .collection('users')
        .where('caregiverEmail',
            isEqualTo: email.toLowerCase())
        .where('role', isEqualTo: 'patient')
        .limit(1)
        .get();

    if (query.docs.isEmpty) {
      return null;
    }

    return UserModel.fromFirestore(
      query.docs.first,
    );
  } catch (e) {
    debugPrint(
      'findPatientByCaregiverEmail error: $e',
    );
    return null;
  }
}  }

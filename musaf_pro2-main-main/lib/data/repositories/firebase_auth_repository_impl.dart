import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../../domain/entities/user_entity.dart';
import '../../domain/repositories/auth_repository.dart';
import '../models/user_model.dart';

class FirebaseAuthRepositoryImpl implements AuthRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  Future<UserEntity?> findPatientByCaregiverEmail(String email) async {
    try {
      var querySnapshot = await _firestore
          .collection('users')
          .where('caregiverEmail', isEqualTo: email)
          .where('role', isEqualTo: 'patient') 
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
      
      await _firestore
          .collection('users')
          .doc(user.uid)
          .set(userModel.toFirestore(), SetOptions(merge: true)); 
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
          .get(); 

      if (!docSnapshot.exists || docSnapshot.data() == null) return null;
      return UserModel.fromFirestore(docSnapshot);
    } catch (e) {
      throw Exception("فشل في جلب بيانات المستخدم: $e");
    }
  }

  @override
  Future<bool> linkCaregiverWithPatient({
    required String caregiverId,
    required String caregiverName,
    required String pairingCode,
  }) async {
    try {
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

      var caregiverRef = _firestore.collection('users').doc(caregiverId);
      batch.update(caregiverRef, {
        'linkedPatientId': patientId,
        'linkedPatientName': patientName,
        'isCaregiverVerified': true,
      });

      var patientRef = _firestore.collection('users').doc(patientId);
      batch.update(patientRef, {
        'isCaregiverVerified': true,
        'pairingCode': FieldValue.delete(), 
      });

      // ✅ هنا نهاية الكود الخاص بفك الارتباط بشكل صحيح
      await batch.commit();
      return true;
    } catch (e) {
      debugPrint("Error during pairing process: $e");
      return false;
    }
  }

  // =================================================================
  // الدوال الجديدة (فك الارتباط، حذف الحساب، رفع الصورة)
  // =================================================================

  @override
  Future<void> unlinkPatientLogic(String currentUserId, String patientId) async {
    try {
      await _firestore.runTransaction((transaction) async {
        final caregiverRef = _firestore.collection('users').doc(currentUserId);
        final patientRef = _firestore.collection('users').doc(patientId);

        final caregiverSnapshot = await transaction.get(caregiverRef);
        final patientSnapshot = await transaction.get(patientRef);

        if (!caregiverSnapshot.exists || !patientSnapshot.exists) {
          throw Exception("عذراً، لم يتم العثور على بيانات المستخدم أو التابع.");
        }

        transaction.update(caregiverRef, {
          'linkedPatientId': FieldValue.delete(), 
          'linkedPatientName': FieldValue.delete(),
        });

        transaction.update(patientRef, {
          'caregiverEmail': FieldValue.delete(), 
          'isCaregiverVerified': false, 
        });
      });

      debugPrint("تم فك الارتباط بنجاح للطرفين.");
    } catch (e) {
      debugPrint("خطأ أثناء فك الارتباط: $e");
      throw Exception("فشلت عملية فك الارتباط، يرجى المحاولة لاحقاً.");
    }
  }

  @override
  Future<void> deleteUserAccountSecurely(String currentPassword) async {
    try {
      User? user = FirebaseAuth.instance.currentUser;
      if (user != null && user.email != null) {
        
        AuthCredential credential = EmailAuthProvider.credential(
          email: user.email!,
          password: currentPassword,
        );
        await user.reauthenticateWithCredential(credential);

        await _firestore.collection('users').doc(user.uid).delete();
        await user.delete();
      }
    } on FirebaseAuthException catch (e) {
      if (e.code == 'wrong-password') {
        throw Exception("كلمة المرور غير صحيحة، يرجى المحاولة مرة أخرى.");
      } else if (e.code == 'network-request-failed') {
         throw Exception("تأكد من اتصالك بالإنترنت.");
      } else {
        throw Exception("حدث خطأ أثناء المصادقة: ${e.message}");
      }
    } catch (e) {
      throw Exception("حدث خطأ غير متوقع أثناء الحذف.");
    }
  }

  @override
  Future<void> uploadProfileImage(String currentUserId, String imagePath) async {
    try {
      String uniqueFileName = '${currentUserId}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      
      final storageRef = FirebaseStorage.instance
          .ref()
          .child('profile_images')
          .child(uniqueFileName); 

      await storageRef.putFile(File(imagePath));
      
      final downloadUrl = await storageRef.getDownloadURL();
      await _firestore
          .collection('users')
          .doc(currentUserId)
          .update({'profileImageUrl': downloadUrl});
          
    } catch (e) {
      debugPrint("خطأ أثناء رفع الصورة: $e");
      throw Exception("فشل رفع الصورة.");
    }
  }
}
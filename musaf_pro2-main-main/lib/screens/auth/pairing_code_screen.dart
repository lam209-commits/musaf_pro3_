import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

// 🚀 استدعاء الزر المخصص الموحد
import 'package:musaf_pro/widgets/custom_button.dart';

class PairingCodeScreen extends StatefulWidget {
  const PairingCodeScreen({super.key});

  @override
  State<PairingCodeScreen> createState() => _PairingCodeScreenState();
}

class _PairingCodeScreenState extends State<PairingCodeScreen> {
  final TextEditingController _codeController = TextEditingController();
  bool _isLoading = false;

  // دالة التحقق من الكود في قاعدة البيانات والربط الحقيقي
  void _verifyCode() async {
    String enteredCode = _codeController.text.trim();

    if (enteredCode.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('يرجى إدخال الكود أولاً', style: TextStyle(fontFamily: 'Cairo'))));
      return;
    }

    setState(() => _isLoading = true);

    try {
      String? currentUserId = FirebaseAuth.instance.currentUser?.uid;
      if (currentUserId != null) {
        
        // 1. البحث في المستودع عن المستخدم (المريض) الذي يملك هذا الكود
        var querySnapshot = await FirebaseFirestore.instance
            .collection('users')
            .where('pairingCode', isEqualTo: enteredCode)
            .limit(1)
            .get();

        if (querySnapshot.docs.isNotEmpty) {
          // ✅ الكود صحيح
          String patientId = querySnapshot.docs.first.id;

          // 2. تحديث الحساب وربط الـ ID
          await FirebaseFirestore.instance.collection('users').doc(currentUserId).update({
            'linkedPatientId': patientId,
          });

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('تم الربط بنجاح! جاري تحويلك...', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
              backgroundColor: Colors.green,
            ));
            
            // 🚀 التوجيه إلى صفحة المريض
            // تأكدي من استبدال '/home' باسم المسار الصحيح لصفحة المريض (مثلاً '/patient_dashboard' أو '/health_data')
            Navigator.pushReplacementNamed(context, '/home'); 
          }
        } else {
          // ❌ الكود خطأ أو غير موجود
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('❌ الكود غير صحيح أو منتهي الصلاحية', style: TextStyle(fontFamily: 'Cairo')),
                backgroundColor: Color(0xFFC62828),
              ),
            );
          }
        }
      }
    } catch (e) {
      debugPrint("Error: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const Color musafRed = Color(0xFFB7131A); // تعريف لون مسعف الأحمر

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: musafRed),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'خطوة 2: إتمام الربط',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontFamily: 'Cairo'),
        ),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 30.0),
        child: Column(
          children: [
            const SizedBox(height: 40),
            // أيقونة المفتاح باللون الأحمر
            const Icon(Icons.vpn_key_outlined, size: 100, color: musafRed),
            const SizedBox(height: 30),

            const Text(
              "أدخل كود الربط",
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, fontFamily: 'Cairo'),
            ),
            const SizedBox(height: 15),
            const Text(
              "يرجى إدخال الكود المكون من 4 أرقام لإتمام عملية الربط بشكل آمن.",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.grey, height: 1.5, fontFamily: 'Cairo'),
            ),

            const SizedBox(height: 50),

            // حقل إدخال الكود
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFFF5F5F5), // رمادي فاتح للخلفية
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: TextField(
                controller: _codeController,
                textAlign: TextAlign.center,
                keyboardType: TextInputType.number,
                maxLength: 4,
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 15,
                  color: musafRed,
                ),
                decoration: const InputDecoration(
                  hintText: "0000",
                  counterText: "",
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(vertical: 20),
                ),
              ),
            ),

            const Spacer(),

            // 🚀 التعديل الاحترافي: ربط الودجت المطور مع تمرير لون مسعف المعتمد بدقة
            _isLoading
                ? const CircularProgressIndicator(color: musafRed)
                : CustomButton(
                    text: 'تأكيد الكود والتالي',
                    isPrimary: true,
                    backgroundColor: musafRed, // اللون الأحمر الكرزي الخاص بكم
                    onPressed: _verifyCode,
                  ),

            const SizedBox(height: 50),
          ],
        ),
      ),
    );
  }
}
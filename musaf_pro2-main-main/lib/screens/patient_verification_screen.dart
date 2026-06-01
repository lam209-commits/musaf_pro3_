import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';

// 🚀 استدعاء الزر المخصص الموحد
import 'package:musaf_pro/widgets/custom_button.dart';

class PatientVerificationScreen extends StatefulWidget {
  const PatientVerificationScreen({super.key});

  @override
  State<PatientVerificationScreen> createState() => _PatientVerificationScreenState();
}

class _PatientVerificationScreenState extends State<PatientVerificationScreen> {
  final TextEditingController _codeController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  // 🚀 دالة التحقق من كود المريض
  void _verifyCode() async {
    String enteredCode = _codeController.text.trim();

    if (enteredCode.isEmpty || enteredCode.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('يرجى إدخال الكود المكون من 6 أرقام بشكل صحيح ⚠️', style: TextStyle(fontFamily: 'Cairo'))
      ));
      return;
    }

    setState(() => _isLoading = true);

    try {
      User? currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null) {
        DocumentSnapshot userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(currentUser.uid)
            .get();

        if (userDoc.exists && userDoc.data() != null) {
          Map<String, dynamic> userData = userDoc.data() as Map<String, dynamic>;
          String? storedCode = userData['patientVerificationCode'];

          if (storedCode != null && storedCode == enteredCode) {
            await FirebaseFirestore.instance.collection('users').doc(currentUser.uid).update({
              'isEmailVerified': true,
              'patientVerificationCode': FieldValue.delete(), 
            });

            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                content: Text('تم التحقق من بريدك بنجاح! ✅', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
                backgroundColor: Colors.green,
              ));
              // التوجيه إلى شاشة البيانات الصحية بعد التحقق
              Navigator.pushNamedAndRemoveUntil(context, '/health_data', (route) => false); 
            }
          } else {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('❌ الكود غير صحيح، يرجى التأكد من البريد الوارد', style: TextStyle(fontFamily: 'Cairo')),
                  backgroundColor: Color(0xFFC62828),
                ),
              );
            }
          }
        }
      }
    } catch (e) {
      debugPrint("Error: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('حدث خطأ في الاتصال ⚠️', style: TextStyle(fontFamily: 'Cairo')), backgroundColor: Colors.red)
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _handleLogout() async {
    try {
      await FirebaseAuth.instance.signOut();
      if (mounted) {
        Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
      }
    } catch (e) {
      debugPrint("Logout Error: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    const Color musafRed = Color(0xFFB7131A);

    return PopScope(
      canPop: false, 
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('يرجى تأكيد الرمز المرسل لإكمال التسجيل 🔒', style: TextStyle(fontFamily: 'Cairo')),
          duration: Duration(seconds: 2),
        ));
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          automaticallyImplyLeading: false, 
          title: const Text(
            'تأكيد البريد الإلكتروني',
            style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontFamily: 'Cairo'),
          ),
          centerTitle: true,
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 30.0),
            child: Column(
              children: [
                const SizedBox(height: 20),
                const Icon(Icons.mark_email_read_outlined, size: 100, color: musafRed),
                const SizedBox(height: 25),

                const Text(
                  "أدخل كود التحقق",
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, fontFamily: 'Cairo'),
                ),
                const SizedBox(height: 12),
                const Text(
                  "أرسلنا كوداً مكوناً من 6 أرقام إلى بريدك الإلكتروني الشخصي. يرجى إدخاله للمتابعة",
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: Colors.grey, height: 1.5, fontFamily: 'Cairo'),
                ),

                const SizedBox(height: 35),

                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5F5F5),
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: TextField(
                    controller: _codeController,
                    textAlign: TextAlign.center,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly], 
                    maxLength: 6, 
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 10,
                      color: musafRed,
                    ),
                    decoration: const InputDecoration(
                      hintText: "000000", 
                      counterText: "",
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(vertical: 15),
                    ),
                  ),
                ),

                const Spacer(),

                _isLoading
                    ? const CircularProgressIndicator(color: musafRed)
                    : CustomButton(
                        text: 'تأكيد ومتابعة',
                        isPrimary: true,
                        backgroundColor: musafRed,
                        onPressed: _verifyCode,
                      ),

                const SizedBox(height: 35),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
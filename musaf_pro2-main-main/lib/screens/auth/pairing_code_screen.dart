import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:musaf_pro/core/theme/app_colors.dart';

import '../../domain/repositories/auth_repository.dart';
import '../../data/repositories/firebase_auth_repository_impl.dart';

import 'package:musaf_pro/widgets/custom_button.dart';

class PairingCodeScreen extends StatefulWidget {
  const PairingCodeScreen({super.key});

  @override
  State<PairingCodeScreen> createState() => _PairingCodeScreenState();
}

class _PairingCodeScreenState extends State<PairingCodeScreen> {
  final TextEditingController _codeController = TextEditingController();
  final AuthRepository _authRepository = FirebaseAuthRepositoryImpl();

  bool _isLoading = false;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _verifyCode() async {
    final enteredCode = _codeController.text.trim();

    if (enteredCode.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'أدخل كود صحيح مكون من 6 أرقام',
            style: TextStyle(fontFamily: 'Tajawal'),
          ),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

   try {
      User? currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null) {
        
        // 🚀 التعديل الجديد: جلب الاسم الحقيقي للمرافق من قاعدة البيانات (Firestore)
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(currentUser.uid)
            .get();

        final String actualCaregiverName = userDoc.data()?['displayName'] ?? 'مرافق';

        // استخدام الدالة الجاهزة في الـ Repository التي تربط الطرفين بـ Batch واحد
        bool isLinked = await _authRepository.linkCaregiverWithPatient(
          caregiverId: currentUser.uid,
          caregiverName: actualCaregiverName, // 👈 تمرير الاسم الحقيقي هنا
          pairingCode: enteredCode,
        );

      if (!mounted) return;

      if (isLinked) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('تم الربط بنجاح', style: TextStyle(fontFamily: 'Tajawal')),
            backgroundColor: Colors.green.shade600,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );

        Navigator.pushNamedAndRemoveUntil(context, '/home', (_) => false);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('الكود غير صحيح أو مستخدم', style: TextStyle(fontFamily: 'Tajawal')),
            backgroundColor: Colors.red.shade600,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } 
    }catch (e) {
      debugPrint('Pairing Error: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = AppColors.primary;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            children: [
              const SizedBox(height: 20),
              
              // أيقونة محسنة مع خلفية دائرية خفيفة تعطي طابعاً مودرن
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.vpn_key_rounded, size: 64, color: color),
              ),

              const SizedBox(height: 24),

              const Text(
                "إدخل كود الربط",
                style: TextStyle(
                  fontSize: 22, 
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Tajawal',
                ),
              ),
              
              const SizedBox(height: 10),
              
              Text(
                "يرجى كتابة الكود المكون من 6 أرقام لربط الحساب بالمريض",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                  fontFamily: 'Tajawal',
                ),
              ),

              const SizedBox(height: 40),

              // حقل إدخال متباعد ومهيأ للأرقام بشكل مريح جداً للبصر
              Container(
                padding: const EdgeInsets.symmetric(vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8F9FA),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.shade200, width: 1.5),
                ),
                child: TextField(
                  controller: _codeController,
                  textAlign: TextAlign.center,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  style: const TextStyle(
                    fontSize: 26, 
                    fontWeight: FontWeight.bold, 
                    letterSpacing: 8,
                  ),
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    counterText: "",
                    hintText: "000000",
                    hintStyle: TextStyle(
                      color: Colors.grey.shade400, 
                      letterSpacing: 8,
                    ),
                  ),
                ),
              ),

              const Spacer(),

              _isLoading
                  ? Center(child: CircularProgressIndicator(color: color))
                  : SizedBox(
                      width: double.infinity,
                      child: CustomButton(
                        text: 'تأكيد الربط',
                        isPrimary: true,
                        backgroundColor: color,
                        onPressed: _verifyCode,
                      ),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}
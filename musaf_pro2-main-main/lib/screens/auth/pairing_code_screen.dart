import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:musaf_pro/core/theme/app_colors.dart';

// 🚀 استدعاء طبقات المعمارية النظيفة وملف الألوان الموحد الخاص بكم
import '../../domain/repositories/auth_repository.dart';
import '../../data/repositories/firebase_auth_repository_impl.dart';

// استدعاء الزر المخصص الموحد
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

  // دالة التحقق من الكود باستخدام المعمارية النظيفة (تحديث ثنائي الاتجاه)
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
        
        // استخدام الدالة الجاهزة في الـ Repository التي تربط الطرفين بـ Batch واحد
        bool isLinked = await _authRepository.linkCaregiverWithPatient(
          caregiverId: currentUser.uid,
          caregiverName: currentUser.displayName ?? 'مرافق',
          pairingCode: enteredCode,
        );

        if (isLinked) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('تم الربط بنجاح! جاري تحويلك... ✅', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
              backgroundColor: Colors.green,
            ));
            
            // 🔄 تم تغيير التوجيه هنا من '/caregiver_home' إلى '/home' وحذف الشاشات السابقة لضمان عدم العودة
            Navigator.pushNamedAndRemoveUntil(context, '/home', (route) => false);
          }
        } else {
          // ❌ الكود خطأ أو تم استخدامه مسبقاً
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('حدث خطأ في الاتصال ⚠️', style: TextStyle(fontFamily: 'Cairo')), backgroundColor: Colors.red)
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // 🎨 اعتماد لون المرافق (البنفسجي) من ملف الألوان المشترك الخاص بكم مباشرة
    final Color caregiverColor = AppColors.primary;

    // استخدام PopScope لمنع الرجوع من إيماءات أو أزرار النظام الخلفية
    return PopScope(
      canPop: false, // 🔒 تعطيل القدرة على الخروج من الشاشة نهائياً بالرجوع
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('يجب إدخال كود الربط للمتابعة ⚠️', style: TextStyle(fontFamily: 'Cairo')),
          duration: Duration(seconds: 2),
        ));
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          automaticallyImplyLeading: false, // 🔒 إخفاء سهم الرجوع التلقائي تماماً
        ),
        body: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 30.0),
          child: Column(
            children: [
              const SizedBox(height: 40),
              Icon(Icons.vpn_key_outlined, size: 100, color: caregiverColor), 
              const SizedBox(height: 30),

              const Text(
                "أدخل كود الربط",
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, fontFamily: 'Cairo'),
              ),
              const SizedBox(height: 15),
              const Text(
                "يرجى إدخال الكود المكون من 6 أرقام لإتمام عملية الربط بشكل آمن",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Colors.grey, height: 1.5, fontFamily: 'Cairo'),
              ),

              const SizedBox(height: 50),

              // حقل إدخال الكود
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
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 10,
                    color: caregiverColor, 
                  ),
                  decoration: const InputDecoration(
                    hintText: "000000", 
                    counterText: "",
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(vertical: 20),
                  ),
                ),
              ),

              const Spacer(),

              _isLoading
                  ? CircularProgressIndicator(color: caregiverColor)
                  : CustomButton(
                      text: 'تأكيد الكود والتالي',
                      isPrimary: true,
                      backgroundColor: caregiverColor, 
                      onPressed: _verifyCode,
                    ),

              const SizedBox(height: 50),
            ],
          ),
        ),
      ),
    );
  }
}
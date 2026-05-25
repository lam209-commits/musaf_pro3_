import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../services/auth_service.dart';

// استدعاء طبقات المعمارية النظيفة والزر الموحد
import '../../domain/repositories/auth_repository.dart';
import '../../data/repositories/firebase_auth_repository_impl.dart';
import 'package:musaf_pro/widgets/custom_button.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final AuthService _auth = AuthService();
  final AuthRepository _authRepository = FirebaseAuthRepositoryImpl();

  final _emailController = TextEditingController();
  final _passController = TextEditingController();
  
  final _formKey = GlobalKey<FormState>();
  
  bool _isLoading = false;
  bool _isObscurePass = true;
  final Color musafRed = const Color(0xFFB7131A);

  void _handleLogin() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isLoading = true);

    try {
      // 1. تسجيل الدخول
      var user = await _auth.signIn(
        _emailController.text.trim(),
        _passController.text.trim(),
      );

      if (user != null) {
        debugPrint("🔵 تسجيل دخول ناجح، جاري جلب بيانات الدور...");
        
        // 2. جلب بيانات المستخدم لمعرفة هل هو مريض أم مرافق
        final userEntity = await _authRepository.getUserData(user.uid);
        
        if (mounted) {
          // 🛑 3. إيقاف دائرة التحميل فوراً
          setState(() => _isLoading = false);
          
          // 🛑 4. التوجيه الجذري والقوي (يمسح الشاشات المعلقة ويوجه بسلاسة)
          if (userEntity != null && userEntity.role == 'caregiver') {
            Navigator.pushNamedAndRemoveUntil(context, '/caregiver_home', (route) => false);
          } else {
            Navigator.pushNamedAndRemoveUntil(context, '/patient_home', (route) => false);
          }
        }
      } 
      
    } on FirebaseAuthException catch (e) {
      // 🛑 إيقاف دائرة التحميل فوراً عند حدوث خطأ
      if (mounted) setState(() => _isLoading = false);

      // 🔍 تحليل نوع الخطأ وعرض رسالة مخصصة للمستخدم:
      if (e.code == 'user-not-found') {
        _showSnackBar('البريد الإلكتروني غير مسجل لدينا ⚠️');
      } else if (e.code == 'wrong-password') {
        _showSnackBar('كلمة المرور غير صحيحة ❌');
      } else if (e.code == 'invalid-email') {
        _showSnackBar('صيغة البريد الإلكتروني خاطئة ⚠️');
      } else if (e.code == 'user-disabled') {
        _showSnackBar('تم حظر هذا الحساب 🚫');
      } else if (e.code == 'invalid-credential') {
        _showSnackBar('تأكد من صحة البريد الإلكتروني وكلمة المرور ⚠️');
      } else {
        _showSnackBar('حدث خطأ: ${e.message}');
      }
      
    } catch (e) {
      debugPrint("🔴 خطأ غير متوقع: $e");
      if (mounted) setState(() => _isLoading = false); 
      _showSnackBar('تأكد من اتصالك بالإنترنت 🌐');
    }
  } void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message, textAlign: TextAlign.right, style: const TextStyle(fontFamily: 'Cairo'))),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 25.0),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(height: 40),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.add_box_rounded, color: musafRed, size: 30),
                      const SizedBox(width: 5),
                      Text(
                        'مُسعف',
                        style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: musafRed, fontFamily: 'Cairo'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 50),
                  Text(
                    'مرحباً بك مجدداً',
                    style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.black87, fontFamily: 'Cairo'),
                  ),
                  const Text(
                    'سجل دخولك للمتابعة في رحلة الرعاية',
                    style: TextStyle(color: Colors.grey, fontSize: 14, fontFamily: 'Cairo'),
                  ),
                  const SizedBox(height: 40),

                  _buildInputLabel("رقم الجوال أو البريد الإلكتروني"),
                  _buildCustomField(
                    controller: _emailController,
                    hint: "example@mail.com",
                    icon: Icons.alternate_email,
                    validator: (val) => (val == null || val.trim().isEmpty) ? 'هذا الحقل مطلوب ⚠️' : null,
                  ),

                  const SizedBox(height: 20),

                  _buildInputLabel("كلمة المرور"),
                  _buildCustomField(
                    controller: _passController,
                    hint: "........",
                    icon: Icons.lock_outline,
                    isPass: _isObscurePass,
                    suffixIcon: IconButton(
                      icon: Icon(_isObscurePass ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: Colors.grey, size: 20),
                      onPressed: () => setState(() => _isObscurePass = !_isObscurePass),
                    ),
                    validator: (val) => (val == null || val.trim().isEmpty) ? 'حقل كلمة المرور مطلوب ⚠️' : null,
                  ),

                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton(
                      onPressed: () {},
                      child: const Text('نسيت كلمة المرور؟', style: TextStyle(color: Colors.blue, fontFamily: 'Cairo', fontSize: 13)),
                    ),
                  ),

                  const SizedBox(height: 30),

                  _isLoading
                      ? CircularProgressIndicator(color: musafRed)
                      : CustomButton(
                          text: 'تسجيل الدخول',
                          isPrimary: true,
                          backgroundColor: musafRed,
                          onPressed: _handleLogin,
                        ),

                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pushNamed(context, '/role_selection'),
                        child: Text('إنشاء حساب جديد', style: TextStyle(color: musafRed, fontWeight: FontWeight.bold, fontFamily: 'Cairo', fontSize: 14)),
                      ),
                      const Text('مستخدم جديد؟', style: TextStyle(fontFamily: 'Cairo', fontSize: 14)),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInputLabel(String label) {
    return Align(
      alignment: Alignment.centerRight,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 8.0),
        child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, fontFamily: 'Cairo', color: Colors.black87)),
      ),
    );
  }

  Widget _buildCustomField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool isPass = false,
    Widget? suffixIcon,
    required String? Function(String?) validator,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(12),
      ),
      child: TextFormField(
        controller: controller,
        obscureText: isPass,
        textAlign: TextAlign.right,
        textDirection: isPass ? TextDirection.ltr : TextDirection.rtl,
        validator: validator,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        style: const TextStyle(fontFamily: 'Cairo', fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black87),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: Colors.black54, fontSize: 13, fontFamily: 'Cairo', fontWeight: FontWeight.bold),
          prefixIcon: Icon(icon, color: Colors.grey),
          suffixIcon: suffixIcon,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 15),
          border: InputBorder.none,
        ),
      ),
    );
  }
}
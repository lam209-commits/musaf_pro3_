import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:musaf_pro/core/theme/app_colors.dart';
import 'package:musaf_pro/screens/auth/PermissionHandle.dart';
import '../../services/auth_service.dart';

// استدعاء طبقات المعمارية النظيفة
import '../../domain/repositories/auth_repository.dart';
import '../../data/repositories/firebase_auth_repository_impl.dart';

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
      var user = await _auth.signIn(
        _emailController.text.trim().toLowerCase(), // توحيد حالة الأحرف لتفادي مشاكل المقارنة
        _passController.text.trim(),
      );
      
      if (user != null) {
        debugPrint("🔵 تسجيل دخول ناجح، جاري جلب بيانات الدور والربط...");
        
        final userEntity = await _authRepository.getUserData(user.uid);
        
        if (mounted) {
          setState(() => _isLoading = false);
          
          if (userEntity == null) {
            _showSnackBar('تعذر جلب بيانات المستخدم ⚠️');
            return;
          }

          // 🔒 1. فحص تأكيد البريد للمريض (إغلاق ثغرة الدخول بدون تحقق)
          if (userEntity.role == 'patient' && userEntity.isEmailVerified != true) {
            Navigator.pushNamedAndRemoveUntil(
              context, 
              '/patient_verification', 
              (route) => false
            );
            return;
          }

          // 🔒 2. منع المرافق من تجاوز شاشة الربط إذا لم يكتمل الربط
          if (userEntity.role == 'caregiver' && (userEntity.linkedPatientId == null || userEntity.linkedPatientId!.isEmpty)) {
            Navigator.pushNamedAndRemoveUntil(
              context, 
              '/pairing', 
              (route) => false
            );
            return;
          } 
          
          // 🚀 3. التوجيه الصحيح بناءً على الدور (تم إزالة ?? patient لأن الدور إلزامي)
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(
              builder: (context) => PermissionHandlerWrapper(userType: userEntity.role),
            ),
            (route) => false,
          );
        }
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) setState(() => _isLoading = false);
      
      if (e.code == 'user-not-found') {
        _showSnackBar('البريد الإلكتروني غير مسجل لدينا ⚠️');
      } else if (e.code == 'wrong-password') {
        _showSnackBar('كلمة المرور غير صحيحة ❌');
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
  }

  void _showForgotPasswordDialog() {
    final resetEmailController = TextEditingController(text: _emailController.text);
    bool isResetting = false;
    
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: const Text(
                'استعادة كلمة المرور',
                style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold),
                textAlign: TextAlign.right,
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'أدخل بريدك الإلكتروني لتعيين كلمة مرور جديدة',
                    style: TextStyle(fontFamily: 'Cairo', fontSize: 13, height: 1.5),
                  ),
                  const SizedBox(height: 15),
                  TextField(
                    controller: resetEmailController,
                    keyboardType: TextInputType.emailAddress,
                    textDirection: TextDirection.ltr,
                    textAlign: TextAlign.right,
                    decoration: InputDecoration(
                      hintText: 'example@mail.com',
                      filled: true,
                      fillColor: Colors.grey[200],
                      prefixIcon: const Icon(Icons.email_outlined, color: Colors.grey),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(vertical: 15),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: isResetting ? null : () => Navigator.pop(context),
                  child: const Text('إلغاء', style: TextStyle(fontFamily: 'Cairo', color: Colors.grey, fontWeight: FontWeight.bold)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: musafRed,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: isResetting ? null : () async {
                    final email = resetEmailController.text.trim();
                    if (email.isEmpty || !email.contains('@')) {
                      _showSnackBar('يرجى إدخال بريد إلكتروني صحيح ⚠️');
                      return;
                    }
                    
                    setStateDialog(() => isResetting = true);
                    
                    try {
                      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
                      if (context.mounted) {
                        Navigator.pop(context);
                        _showSnackBar('تم إرسال رابط استعادة كلمة المرور بنجاح ✅');
                      }
                    } on FirebaseAuthException catch (e) {
                      setStateDialog(() => isResetting = false);
                      if (e.code == 'user-not-found') {
                        _showSnackBar('لا يوجد حساب مسجل بهذا البريد ⚠️');
                      } else if (e.code == 'invalid-email') {
                        _showSnackBar('صيغة البريد الإلكتروني غير صحيحة ⚠️');
                      } else {
                        _showSnackBar('حدث خطأ أثناء الإرسال. تحقق من الإنترنت 📡');
                      }
                    } catch (e) {
                      setStateDialog(() => isResetting = false);
                      _showSnackBar('حدث خطأ غير متوقع ⚠️');
                    }
                  },
                  child: isResetting
                      ? const SizedBox(
                          height: 20, width: 20,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                        )
                      : const Text('إرسال الرابط', style: TextStyle(fontFamily: 'Cairo', color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          textAlign: TextAlign.right,
          style: const TextStyle(fontFamily: 'Cairo', color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        margin: const EdgeInsets.all(15),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passController.dispose();
    super.dispose();
  }

  // ==========================================
  // 🎨 واجهة المستخدم (UI)
  // ==========================================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Directionality(
          textDirection: TextDirection.rtl,
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 25.0),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 20),
                    
                    // الشعار
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.add_box_rounded, color: musafRed, size: 35),
                        const SizedBox(width: 8),
                        Text(
                          'مُسعف',
                          style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: musafRed, fontFamily: 'Cairo'),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 40),
                    
                    // العناوين العلوية
                    const Text(
                      'تسجيل الدخول',
                      style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.black87, fontFamily: 'Cairo'),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'أدخل تفاصيل حساب مُسعف الخاص بك.',
                      style: TextStyle(color: Colors.grey.shade700, fontSize: 15, fontFamily: 'Cairo'),
                    ),
                    
                    const SizedBox(height: 40),
                    
                    // حقل البريد الإلكتروني
                    _buildInputLabel("البريد الإلكتروني"),
                    _buildCustomField(
                      controller: _emailController,
                      hint: "example@mail.com",
                      isEmail: true,
                      validator: (val) => (val == null || val.trim().isEmpty) ? 'هذا الحقل مطلوب ⚠️' : null,
                    ),
                    
                    const SizedBox(height: 25),
                    
                    // حقل كلمة المرور
                    _buildInputLabel("كلمة السر"),
                    _buildCustomField(
                      controller: _passController,
                      hint: "••••••••",
                      isPass: _isObscurePass,
                      isPasswordField: true,
                      suffixIcon: IconButton(
                        icon: Icon(_isObscurePass ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: Colors.black54, size: 22),
                        onPressed: () => setState(() => _isObscurePass = !_isObscurePass),
                      ),
                      validator: (val) => (val == null || val.trim().isEmpty) ? 'حقل كلمة المرور مطلوب ⚠️' : null,
                    ),
                    
                    const SizedBox(height: 10),
                    
                    // زر نسيت كلمة المرور
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton(
                        onPressed: _showForgotPasswordDialog,
                        style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(50, 30), tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                        child: const Text('نسيت كلمة المرور؟', style: TextStyle(color: Colors.grey, fontFamily: 'Cairo', fontSize: 13, fontWeight: FontWeight.bold)),
                      ),
                    ),
                    
                    const SizedBox(height: 35),
                    
                    // زر تسجيل الدخول
                    _isLoading
                        ? Center(child: CircularProgressIndicator(color: musafRed))
                        : SizedBox(
                            width: double.infinity,
                            height: 55,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: musafRed,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                elevation: 0,
                              ),
                              onPressed: _handleLogin,
                              child: const Text('تسجيل الدخول', style: TextStyle(fontFamily: 'Cairo', color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                            ),
                          ),
                          
                    const SizedBox(height: 30),
                    
                    // رابط إنشاء الحساب السفلي
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text('جديد في مُسعف؟', style: TextStyle(fontFamily: 'Cairo', fontSize: 14, color: Colors.black87)),
                        TextButton(
                          onPressed: () => Navigator.pushNamed(context, '/role_selection'),
                          child: Text('إنشاء حساب', style: TextStyle(color: musafRed, fontWeight: FontWeight.bold, fontFamily: 'Cairo', fontSize: 14, decoration: TextDecoration.underline, decorationColor: musafRed)),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // دالة مساعدة لإنشاء العناوين
  Widget _buildInputLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0, right: 4.0),
      child: Text(
        label,
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, fontFamily: 'Cairo', color: Colors.black87),
      ),
    );
  }

  // دالة مساعدة لإنشاء الحقول
  Widget _buildCustomField({
    required TextEditingController controller,
    required String hint,
    bool isPass = false,
    bool isEmail = false,
    bool isPasswordField = false,
    Widget? suffixIcon,
    required String? Function(String?) validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: isPass,
      textAlign: TextAlign.right,
      textDirection: isEmail ? TextDirection.ltr : null,
      validator: validator,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      style: const TextStyle(fontFamily: 'Cairo', fontSize: 15, fontWeight: FontWeight.w600, color: Colors.black87),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.grey, fontSize: 14, fontFamily: 'Cairo'),
        suffixIcon: suffixIcon,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.grey.shade400, width: 1.0),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: musafRed, width: 2.0),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Colors.red, width: 1.0),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Colors.red, width: 2.0),
        ),
      ),
    );
  }
}
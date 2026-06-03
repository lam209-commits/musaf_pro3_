import 'package:flutter/material.dart';
import 'dart:math';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:musaf_pro/core/theme/app_colors.dart';

import '../../services/auth_service.dart';
import '../../services/email_service.dart';
import '../../domain/entities/user_entity.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../data/repositories/firebase_auth_repository_impl.dart';
import 'package:musaf_pro/widgets/custom_button.dart';
import 'package:flutter/services.dart'; // 👈 أضيفي هذا السطر في الأعلى

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final AuthService _auth = AuthService();
  final AuthRepository _authRepository = FirebaseAuthRepositoryImpl();

  // الحقول الأساسية
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _passController = TextEditingController();
  final _confirmPassController = TextEditingController();

  // حقول المريض فقط
  final _caregiverEmailController = TextEditingController();
  String? _selectedRelation;

  // مفتاح عالمي لتتبع حالة حقول الاستمارة (Form Key)
  final _formKey = GlobalKey<FormState>();

  bool _isLoading = false;
  final Color primaryRed = const Color(0xFFB7131A);
  bool get isPatient => userRole == 'patient';
Color get buttonColor => isPatient ? primaryRed : AppColors.primary;

  String? userRole;

  // متغيرات التحكم في إظهار وإخفاء كلمة السر (العين)
  bool _isObscurePass = true;
  bool _isObscureConfirmPass = true;
  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _passController.dispose();
    _confirmPassController.dispose();
    _caregiverEmailController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    userRole = ModalRoute.of(context)?.settings.arguments as String?;
  }

  // دالة فحص قوة كلمة السر المعتمدة (Regex Validation)
  bool _isPasswordStrong(String password) {
    if (password.length < 8) return false; 
    if (!password.contains(RegExp(r'[A-Z]'))) return false; 
    if (!password.contains(RegExp(r'[a-z]'))) return false; 
    if (!password.contains(RegExp(r'[0-9]'))) return false; 
    if (!password.contains(RegExp(r'[!@#\$&*%~]'))) return false; 
    return true;
  }

  // 🚀 الدالة المدمجة والمنظمة بالكامل لمعالجة التسجيل
 // 🚀 الدالة المدمجة والمنظمة بالكامل لمعالجة التسجيل (نسخة آمنة ومحسنة)
 // 🚀 الدالة المدمجة والمنظمة بالكامل لمعالجة التسجيل (نسخة آمنة ومحسنة)
 // 🚀 الدالة المدمجة والمنظمة بالكامل لمعالجة التسجيل (النسخة المعمارية النظيفة)
  Future<void> _handleRegister() async {
    if (!_formKey.currentState!.validate()) return;

    if (userRole == 'patient' && _selectedRelation == null) {
      _showErrorSnackBar('يرجى تحديد صلة القرابة للمرافق ⚠️');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final email = _emailController.text.trim().toLowerCase();
      final password = _passController.text.trim();
      final caregiverEmail = _caregiverEmailController.text.trim().toLowerCase();

      // منع المستخدم من إدخال نفس البريد (نقطة ممتازة في تجربة المستخدم HCI)
      if (userRole == 'patient' && email == caregiverEmail) {
        _showErrorSnackBar('لا يمكن استخدام نفس البريد للمريض والمرافق ⚠️');
        return;
      }

      // =========================
      // 1. إنشاء حساب Firebase Auth
      // =========================
      final userCredential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final uid = userCredential.user!.uid;

      // =========================
      // 2. توليد الأكواد (للمريض فقط)
      // 2. توليد الأكواد
      String? generatedPairingCode;
      String? generatedVerificationCode;

      if (userRole == 'patient') {
        generatedPairingCode = (Random.secure().nextInt(900000) + 100000).toString();
        generatedVerificationCode = (Random.secure().nextInt(900000) + 100000).toString();
      }

      // =========================
      // 3. بناء الكيان الأساسي (بدون أي ربط مبدئي)
      // =========================
      final newUser = UserEntity(
        uid: uid,
        displayName: _nameController.text.trim(),
        phoneNumber: "+967 ${_phoneController.text.trim()}",
        role: userRole!,
        email: email,
        caregiverEmail: userRole == 'patient' ? caregiverEmail : null,
        relation: userRole == 'patient' ? _selectedRelation : null,
        
        pairingCode: generatedPairingCode, // يُحفظ داخل المريض فقط
patientVerificationCode: generatedVerificationCode, // 🚀 👈 تمرير الكود لقاعدة البيانات 
       isLinked: false, // لا يوجد ربط وقت التسجيل نهائياً
        isEmailVerified: userRole == 'patient' ? false : null,
      );

      // =========================
      // 4. حفظ المستخدم في Firestore
      // =========================
      await _authRepository.saveUserData(newUser);

      // =========================
      // 5. التوجيه وإرسال الإيميلات
      // =========================
      if (userRole == 'patient') {
        // المريض: نرسل كود الربط لبريد المرافق، وكود التحقق لبريد المريض نفسه
        await EmailService.sendPairingCode(
          toEmail: caregiverEmail,
          pairingCode: generatedPairingCode!,
        );

        await EmailService.sendPatientVerificationCode(
          toEmail: email,
          verificationCode: generatedVerificationCode!,
        );

        if (mounted) {
          // توجيه المريض لصفحة التحقق من بريده
          Navigator.pushReplacementNamed(context, '/patient_verification');
        }
      } else {
        // المرافق: تم إنشاء حسابه بنجاح، يتوجه فوراً لصفحة الربط لإدخال الكود
        if (mounted) {
          Navigator.pushReplacementNamed(context, '/pairing');
        }
      }
    } on FirebaseAuthException catch (e) {
      if (e.code == 'email-already-in-use') {
        _showErrorSnackBar('البريد الإلكتروني مستخدم مسبقاً ⚠️');
      } else {
        _showErrorSnackBar('حدث خطأ في المصادقة: ${e.message}');
      }
    } catch (e) {
      debugPrint("Firebase Error: $e");
      _showErrorSnackBar('حدث خطأ أثناء الحفظ في قاعدة البيانات ⚠️'); // 👈 هذا سيكشف لنا إذا كانت قاعدة البيانات ترفض الحفظ
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
icon: Icon(
    Icons.arrow_back, 
    // الشرط: إذا كان المريض (userRole == 'patient') استخدم الأحمر، وإلا استخدم لون المرافق (AppColors.primary)
    color: userRole == 'patient' ?primaryRed : AppColors.primary, 
  ),           onPressed: () => Navigator.pop(context), // لون المرافق الثابت          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          userRole == 'patient' ? 'تسجيل مريض' : 'تسجيل مرافق',
          style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontFamily: 'Cairo'),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 25.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              const SizedBox(height: 10),
              
              _buildFieldLabel("الاسم الكامل", Icons.person_outline),
              _buildCustomTextField(
                controller: _nameController, 
                hint: "الاسم الثلاثي",
                validator: (val) => val == null || val.trim().isEmpty ? 'الاسم الكامل مطلوب ⚠️' : null,
              ),
              
              const SizedBox(height: 15),
              
              _buildFieldLabel("رقم الجوال", Icons.phone_android_outlined),
              _buildCustomTextField(
                controller: _phoneController, 
                hint: "7XXXXXXXX", 
                isNumber: true, 
                prefixText: "+967 ",
                validator: (val) {
                  if (val == null || val.trim().isEmpty) return 'رقم الجوال مطلوب ⚠️';
                  if (val.trim().length != 9 || !val.trim().startsWith('7')) {
                    return 'يجب أن يتكون من 9 أرقام ويبدأ بـ 7 ⚠️';
                  }
                  return null;
                },
              ),
              
              const SizedBox(height: 15),
              
              _buildFieldLabel("البريد الإلكتروني", Icons.email_outlined),
              _buildCustomTextField(
                controller: _emailController, 
                hint: "example@mail.com",
                validator: (val) {
                  if (val == null || val.trim().isEmpty) return 'البريد الإلكتروني مطلوب ⚠️';
                  final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
                  if (!emailRegex.hasMatch(val.trim())) return 'صيغة البريد الإلكتروني غير صحيحة ⚠️';
                  return null;
                },
              ),
              
              if (userRole == 'patient') ...[
                const SizedBox(height: 15),
                _buildFieldLabel("بريد المرافق ( للربط )", Icons.alternate_email_rounded),
                _buildCustomTextField(
                  controller: _caregiverEmailController, 
                  hint: "caregiver@mail.com",
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) return 'بريد المرافق مطلوب ⚠️';
                    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
                    if (!emailRegex.hasMatch(val.trim())) return 'صيغة البريد غير صحيحة ⚠️';
                    return null;
                  },
                ),
                const SizedBox(height: 15),
                _buildFieldLabel("صلة القرابة للمرافق", Icons.people_outline),
                _buildDropdownField(),
              ],
              
              const SizedBox(height: 15),
              
              _buildFieldLabel("كلمة المرور", Icons.lock_outline),
              _buildCustomTextField(
                controller: _passController, 
                hint: "........", 
                isPass: _isObscurePass,
                suffixIcon: IconButton(
                  icon: Icon(_isObscurePass ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: Colors.grey, size: 20),
                  onPressed: () => setState(() => _isObscurePass = !_isObscurePass),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) return 'كلمة المرور مطلوبة ⚠️';
                  if (!_isPasswordStrong(val.trim())) {
                    return 'ضعيفة! يلزم 8 خانات (رموز، أرقام، حروف عريضة وصغيرة) ⚠️';
                  }
                  return null;
                },
              ),
              
              const SizedBox(height: 15),
              
              _buildFieldLabel("تأكيد كلمة المرور", Icons.lock_reset_outlined),
              _buildCustomTextField(
                controller: _confirmPassController, 
                hint: "........", 
                isPass: _isObscureConfirmPass,
                suffixIcon: IconButton(
                  icon: Icon(_isObscureConfirmPass ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: Colors.grey, size: 20),
                  onPressed: () => setState(() => _isObscureConfirmPass = !_isObscureConfirmPass),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) return 'تأكيد كلمة المرور مطلوب ⚠️';
                  if (val.trim() != _passController.text.trim()) return 'كلمات المرور غير متطابقة ⚠️';
                  return null;
                },
              ),
              
              const SizedBox(height: 40),
              
            _isLoading
    ? CircularProgressIndicator(color: buttonColor)
    : CustomButton(
        text: isPatient ? 'إنشاء حساب ومتابعة' : 'إنشاء حساب مرافق',
        isPrimary: true,
        backgroundColor: buttonColor, // الزر سيتلون تلقائياً (أحمر للمريض، بنفسجي للمرافق)
        onPressed: _handleRegister,
      ),
const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFieldLabel(String label, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, fontFamily: 'Cairo')),
          const SizedBox(width: 8),
          Icon(icon, size: 18, color: Colors.grey[600]),
        ],
      ),
    );
  }

  // 🌟 دالة بناء الحقل المستقرة والمحسنة هندسياً لتحافظ على نفس حجم وخلفية الكود القديم تماماً
 // 🌟 دالة بناء الحقل المستقرة والمحسنة لمنع الرموز والحروف في حقل الهاتف
 // 🌟 دالة بناء الحقل (النسخة الاحترافية المتوافقة مع شاشة الدخول)
  Widget _buildCustomTextField({
    required TextEditingController controller, 
    required String hint, 
    bool isPass = false, 
    bool isNumber = false, 
    String? prefixText,
    Widget? suffixIcon,
    TextInputType? keyboardType,
    required String? Function(String?) validator,
  }) {
    // 🎨 تحديد لون التحديد حسب نوع المستخدم (أحمر للمريض، بنفسجي للمرافق)
    final Color activeColor = userRole == 'patient' ? primaryRed : AppColors.primary;

    return TextFormField( // تم إزالة الـ Container الخارجي والاعتماد على خصائص الحقل مباشرة
      controller: controller,
      obscureText: isPass,
      textAlign: TextAlign.right,
      textDirection: TextDirection.ltr, 
      maxLength: isNumber ? 9 : null,
      validator: validator,
      // ⏳ التحقق يحدث بعد تفاعل المستخدم، وتظهر الرسالة بهدوء بالأسفل
      autovalidateMode: AutovalidateMode.onUserInteraction, 
      
      inputFormatters: isNumber 
          ? [FilteringTextInputFormatter.digitsOnly] 
          : null,
          
      style: const TextStyle(fontFamily: 'Cairo', fontSize: 14, letterSpacing: 1.0, fontWeight: FontWeight.w600),
      keyboardType: keyboardType ?? (isNumber ? TextInputType.number : TextInputType.text),
      
      decoration: InputDecoration(
        counterText: "", 
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.grey, fontSize: 13, fontFamily: 'Cairo', fontWeight: FontWeight.normal),
        
        // 🎨 لون خلفية الحقل
        fillColor: const Color(0xFFF5F5F5),
        filled: true,
        
        prefixIcon: prefixText != null 
            ? Padding(
                padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
                child: Text(prefixText, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87, fontSize: 14, fontFamily: 'Cairo')),
              )
            : null,
        suffixIcon: suffixIcon,
        isDense: true,
        contentPadding: const EdgeInsets.all(16), // مساحة داخلية مريحة للعين
        
        // 🚀 1. الحدود في الحالة العادية (بدون أخطاء أو تركيز)
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.transparent),
        ),
        
        // 🚀 2. الحدود عند الضغط على الحقل (يتلون بلون المستخدم)
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: activeColor, width: 1.5),
        ),
        
        // 🚀 3. الحدود عند وجود خطأ (أحمر)
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.redAccent, width: 1.0),
        ),
        
        // 🚀 4. الحدود عند وجود خطأ والمستخدم يحاول التعديل
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.red, width: 2.0),
        ),
        
        // 📝 تنسيق رسالة الخطأ لتظهر بشكل أنيق أسفل الحقل مباشرة
        errorStyle: const TextStyle(
          fontFamily: 'Cairo', 
          fontSize: 12, 
          color: Colors.redAccent, 
          height: 1.2, 
          fontWeight: FontWeight.bold
        ),
      ),
    );
  }
  Widget _buildDropdownField() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 15),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5F5), 
        borderRadius: BorderRadius.circular(12),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedRelation,
          isExpanded: true,
          hint: const Align(
            alignment: Alignment.centerRight, 
            child: Text('اختر صلة القرابة', style: TextStyle(fontFamily: 'Cairo', fontSize: 13)),
          ),
          items: ['أب/أم', 'ابن/ابنة', 'أخ/أخت', 'زوج/زوجة', 'أخرى'].map((e) => DropdownMenuItem(
            value: e,
            child: Align(alignment: Alignment.centerRight, child: Text(e, style: const TextStyle(fontFamily: 'Cairo', fontSize: 14))),
          )).toList(),
          onChanged: (val) => setState(() => _selectedRelation = val),
        ),
      ),
    );
  }
  void _showErrorSnackBar(String message) {
    // التأكد من أن الكلاس لا يزال موجوداً في الذاكرة
    if (!mounted) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message, 
          textAlign: TextAlign.right,
          style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 14)
        ),
        backgroundColor: primaryRed, // اللون الأحمر الخاص بكِ
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(15),
        duration: const Duration(seconds: 4),
      ),
    );
  }
}
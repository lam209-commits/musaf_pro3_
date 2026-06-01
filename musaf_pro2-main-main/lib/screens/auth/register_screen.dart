import 'package:flutter/material.dart';
import 'dart:math';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:musaf_pro/core/theme/app_colors.dart';

import '../../services/auth_service.dart';
import '../../services/email_service.dart';
import '../../domain/entities/user_entity.dart';
import '../../domain/repositories/auth_repository.dart';
import 'package:musaf_pro/screens/main_dashboardF_screen.dart'; // تأكدي من المسار الصحيح للملف
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
  Future<void> _handleRegister() async {
    // 1. التحقق من الحقول الأساسية
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // 2. التحقق من صلة القرابة إذا كان المستخدم مريضاً
    if (userRole == 'patient' && _selectedRelation == null) {
      _showErrorSnackBar('يرجى تحديد صلة القرابة للمرافق ⚠️');
      return;
    }

    // 🚀 [تعديل هام]: تحويل الإيميلات إلى حروف صغيرة لمنع مشاكل التكرار في قاعدة البيانات
    String enteredEmail = _emailController.text.trim().toLowerCase();
    String caregiverEmail = _caregiverEmailController.text.trim().toLowerCase();

    // 🚀 [تعديل هام]: منع المريض من وضع إيميله الشخصي كإيميل للمرافق
    if (userRole == 'patient' && enteredEmail == caregiverEmail) {
      _showErrorSnackBar('لا يمكن استخدام نفس البريد للمريض والمرافق ⚠️');
      return;
    }

    setState(() => _isLoading = true);

    try {
      String phoneRaw = _phoneController.text.trim();
      String fullPhoneNumber = "+967 $phoneRaw"; 
      String password = _passController.text.trim();
      
      String? linkedPatientId;
      String? linkedPatientName; 

      debugPrint("🔵 بدأنا التسجيل النظيف بدور: $userRole");

      // 3. إذا كان مرافقاً، نتحقق أولاً هل أضافه مريض أم لا
      if (userRole == 'caregiver') {
        debugPrint("🔵 استدعاء المستودع للبحث عن التابع بالسيرفر...");
        final patientEntity = await _authRepository.findPatientByCaregiverEmail(enteredEmail);

        if (patientEntity == null) {
          _showErrorSnackBar('❌ هذا البريد غير مصرح له! يجب أن يضيفك المريض أولاً.');
          setState(() => _isLoading = false);
          return;
        } else {
          linkedPatientId = patientEntity.uid;
          linkedPatientName = patientEntity.displayName.isNotEmpty ? patientEntity.displayName : 'التابع';
        }
      }

      // 4. إنشاء الحساب المباشر في Firebase Auth
      UserCredential userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: enteredEmail,
        password: password,
      );

      String uid = userCredential.user!.uid;

      // 🚀 [تعديل هام]: توليد كود آمن تماماً من 6 أرقام لتجنب أي احتمالية للربط الخاطئ
      String? generatedPairingCode = userRole == 'patient' 
          ? (Random.secure().nextInt(900000) + 100000).toString() 

          : null;
          // 🚀 توليد كود للمريض نفسه (للتحقق من إيميله)
      String? patientVerificationCode = userRole == 'patient' 
          ? (Random.secure().nextInt(900000) + 100000).toString() 
          : null;

      // 5. تجهيز هيكل البيانات (UserEntity)
     UserEntity newUserEntity = UserEntity(
        uid: uid,
        displayName: _nameController.text.trim(),
        phoneNumber: fullPhoneNumber,
        role: userRole!,
        email: enteredEmail,
        caregiverEmail: userRole == 'patient' ? caregiverEmail : null,
        relation: userRole == 'patient' ? _selectedRelation : null,
        pairingCode: generatedPairingCode, // الكود الذي سيذهب للمرافق
        patientVerificationCode: patientVerificationCode, // 👈 الكود الذي سيذهب للمريض
        isEmailVerified: userRole == 'patient' ? false : null, // 👈 حالة تحقق إيميل المريض
        isCaregiverVerified: userRole == 'patient' ? false : null,
        linkedPatientId: userRole == 'caregiver' ? linkedPatientId : null,
        linkedPatientName: userRole == 'caregiver' ? linkedPatientName : null,
      );

      // 6. حفظ البيانات في Firestore مع حماية التراجع (Rollback)
      try {
        await _authRepository.saveUserData(newUserEntity);
      } catch (e) {
        // 🚀 [تعديل هام]: إذا فشل الحفظ في Firestore، نحذف حساب Auth لمنع الحسابات اليتيمة
        await userCredential.user?.delete();
        throw Exception('فشل حفظ بيانات المستخدم في قاعدة البيانات، تم التراجع.');
      }

      // 7. إرسال الإيميلات والتوجيه
      // 7. إرسال الإيميلات والتوجيه
      if (userRole == 'patient') {
        // 1. إرسال كود الربط لإيميل المرافق
        await EmailService.sendPairingCode(
          toEmail: newUserEntity.caregiverEmail!,
          pairingCode: newUserEntity.pairingCode!,
        );
        
        // 2. 👈 إرسال كود التحقق لإيميل المريض الشخصي
        await EmailService.sendPatientVerificationCode(
          toEmail: newUserEntity.email,
          verificationCode: patientVerificationCode!, 
        );

        // 3. 👈 التوجيه: بدلاً من الذهاب لمعلوماته الصحية مباشرة، نوجهه لشاشة التحقق من الإيميل!
        if (mounted) Navigator.pushReplacementNamed(context, '/patient_verification'); 
        
      } else if (userRole == 'caregiver') {
        // المرافق ينتقل لصفحة إدخال الكود
        if (mounted) Navigator.pushReplacementNamed(context, '/pairing'); 
      }

    } on FirebaseAuthException catch (e) {
      if (e.code == 'email-already-in-use') {
        _showErrorSnackBar('هذا البريد مسجل مسبقاً في النظام! يرجى استخدام بريد آخر ⚠️');
      } 
      else if (e.code == 'weak-password') {
        _showErrorSnackBar('كلمة المرور ضعيفة جداً، يرجى اختيار كلمة أقوى ⚠️');
      } 
      else if (e.code == 'network-request-failed') {
        _showErrorSnackBar('عذراً، فشل الاتصال بالشبكة.. تحقق من الإنترنت 📡');
      } 
      else {
        _showErrorSnackBar('حدث خطأ أثناء التسجيل: ${e.message}');
      }
    } catch (e) {
      _showErrorSnackBar('حدث خطأ غير متوقع، يرجى إعادة المحاولة ⚠️');
      debugPrint("Error: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
  // دالة عرض رسائل الخطأ بتصميم موحد
  // دالة عرض رسائل الخطأ بتصميم ولون موحد مع التطبيق
  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message, 
          textAlign: TextAlign.right,
          style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 14)
        ),
        backgroundColor: primaryRed, 
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(15),
        duration: const Duration(seconds: 4),
      ),
    );
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
  Widget _buildCustomTextField({
    required TextEditingController controller, 
    required String hint, 
    bool isPass = false, 
    bool isNumber = false, 
    String? prefixText,
    Widget? suffixIcon,
    TextInputType? keyboardType, // 👈 1. أضفنا هذا السطر
    required String? Function(String?) validator,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5F5), 
        borderRadius: BorderRadius.circular(12),
      ),
      child: TextFormField(
        controller: controller,
        obscureText: isPass,
        textAlign: TextAlign.right,
        textDirection: TextDirection.ltr, 
        maxLength: isNumber ? 9 : null,
        validator: validator,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        
        // 🚀 التعديل هنا: منع المستخدم من إدخال أي شيء عدا الأرقام إذا كان الحقل رقماً
        inputFormatters: isNumber 
            ? [FilteringTextInputFormatter.digitsOnly] 
            : null,
            
        style: const TextStyle(fontFamily: 'Cairo', fontSize: 14, letterSpacing: 1.0, fontWeight: FontWeight.w500),
        keyboardType: keyboardType ?? (isNumber ? TextInputType.number : TextInputType.text), // 👈 2. التعديل هنا
        decoration: InputDecoration(
          counterText: "", 
          hintText: hint,
          hintStyle: const TextStyle(color: Colors.grey, fontSize: 13, fontFamily: 'Cairo', fontWeight: FontWeight.normal),
          prefixIcon: prefixText != null 
              ? Padding(
                  padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
                  child: Text(prefixText, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87, fontSize: 14, fontFamily: 'Cairo')),
                )
              : null,
          suffixIcon: suffixIcon,
          isDense: true,
          contentPadding: const EdgeInsets.all(15),
          border: const OutlineInputBorder(borderSide: BorderSide.none),
          enabledBorder: const OutlineInputBorder(borderSide: BorderSide.none),
          focusedBorder: const OutlineInputBorder(borderSide: BorderSide.none),
          errorBorder: const OutlineInputBorder(borderSide: BorderSide.none),
          focusedErrorBorder: const OutlineInputBorder(borderSide: BorderSide.none),
          errorStyle: const TextStyle(fontFamily: 'Cairo', fontSize: 11, color: Colors.redAccent, height: 1.0, fontWeight: FontWeight.bold),
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
}
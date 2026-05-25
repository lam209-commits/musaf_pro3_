import 'package:flutter/material.dart';
import 'dart:math';
import '../../services/auth_service.dart';
import '../../services/email_service.dart';

// استدعاء طبقات المعمارية النظيفة والزر الموحد المعتمد
import '../../domain/entities/user_entity.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../data/repositories/firebase_auth_repository_impl.dart';
import 'package:musaf_pro/widgets/custom_button.dart';

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
  String? userRole;

  // متغيرات التحكم في إظهار وإخفاء كلمة السر (العين)
  bool _isObscurePass = true;
  bool _isObscureConfirmPass = true;

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

  void _handleRegister() async {
    // تشغيل محرك الفحص للتأكد من تعبئة الحقول وصحتها
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (userRole == 'patient' && _selectedRelation == null) {
      _showError('يرجى تحديد صلة القرابة للمرافق');
      return;
    }

    String phoneRaw = _phoneController.text.trim();
    String password = _passController.text.trim();

    setState(() => _isLoading = true);

    try {
      String enteredEmail = _emailController.text.trim();
      String fullPhoneNumber = "+967 $phoneRaw"; 
      String? linkedPatientId;
      String? linkedPatientName; 

      debugPrint("🔵 الخطوة 1: بدأنا التسجيل النظيف بدور: $userRole");

      if (userRole == 'caregiver') {
        debugPrint("🔵 الخطوة 2: استدعاء المستودع للبحث عن التابع بالسيرفر...");
        final patientEntity = await _authRepository.findPatientByCaregiverEmail(enteredEmail);

        if (patientEntity == null) {
          _showError('❌ هذا البريد غير مصرح له! يجب أن يضيفك المريض أولاً.');
          setState(() => _isLoading = false);
          return;
        } else {
          linkedPatientId = patientEntity.uid;
          linkedPatientName = patientEntity.displayName.isNotEmpty ? patientEntity.displayName : 'التابع';
          debugPrint("🔵 الخطوة 4: تم جلب اسم التابع بنجاح: $linkedPatientName");
        }
      }

      debugPrint("🔵 الخطوة 5: جاري إنشاء الحساب في Firebase Auth...");
      // ✅ الاستدعاء الصحيح
var user = await _auth.registerUser(
  email: enteredEmail,
  password: password,
  displayName: _nameController.text.trim(), // أو اسم المتغير الذي يحفظ اسم المستخدم لديكِ
  phoneNumber: _phoneController.text.trim(), // أو اسم المتغير الذي يحفظ رقم الجوال
  role: userRole!, // تمرير الدور (مريض أو مرافق)
);

      if (user == null) {
        setState(() => _isLoading = false);
        return;
      }

      UserEntity newUserEntity = UserEntity(
        uid: user.uid,
        displayName: _nameController.text.trim(),
        phoneNumber: fullPhoneNumber,
        role: userRole!,
        email: enteredEmail,
        caregiverEmail: userRole == 'patient' ? _caregiverEmailController.text.trim() : null,
        relation: userRole == 'patient' ? _selectedRelation : null,
        pairingCode: userRole == 'patient' ? (Random().nextInt(9000) + 1000).toString() : null,
        isCaregiverVerified: userRole == 'patient' ? false : null,
        linkedPatientId: userRole == 'caregiver' ? linkedPatientId : null,
        linkedPatientName: userRole == 'caregiver' ? linkedPatientName : null,
      );

      await _authRepository.saveUserData(newUserEntity);

      if (userRole == 'patient') {
        await EmailService.sendPairingCode(
          toEmail: newUserEntity.caregiverEmail!,
          pairingCode: newUserEntity.pairingCode!,
        );
        if (mounted) Navigator.pushReplacementNamed(context, '/pairing');
      } else if (userRole == 'caregiver') {
        if (mounted) Navigator.pushReplacementNamed(context, '/caregiver_home');
      }
    } catch (e) {
      _showError('تنبيه: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg, textAlign: TextAlign.right, style: const TextStyle(fontFamily: 'Cairo'))),
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
          icon: Icon(Icons.arrow_back, color: primaryRed),
          onPressed: () => Navigator.pop(context),
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
                _buildFieldLabel("بريد المرافق (لإرسال الكود)", Icons.alternate_email_rounded),
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
                  ? CircularProgressIndicator(color: primaryRed)
                  : CustomButton(
                      text: userRole == 'patient' ? 'إنشاء حساب ومتابعة' : 'إنشاء حساب مرافق',
                      isPrimary: true,
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
  Widget _buildCustomTextField({
    required TextEditingController controller, 
    required String hint, 
    bool isPass = false, 
    bool isNumber = false, 
    String? prefixText,
    Widget? suffixIcon,
    required String? Function(String?) validator,
  }) {
    return Container(
      // تطابق كامل مع أبعاد ولون وكيرف حقول الكود القديم الأصلي
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
        // تفعيل خط كيرو الموحد للنص المكتوب
        style: const TextStyle(fontFamily: 'Cairo', fontSize: 14, letterSpacing: 1.0, fontWeight: FontWeight.w500),
        keyboardType: isNumber ? TextInputType.number : TextInputType.emailAddress,
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
          
          // 🔒 ضغط المحتوى الداخلي هندسياً ليحافظ على نفس الارتفاع القديم (15) للـ Padding
          isDense: true,
          contentPadding: const EdgeInsets.all(15),
          
          // حجب الخطوط والإطارات تماماً لمنع التشوه الرأسي عند ظهور التنبيه الأحمر بالأسفل
          border: const OutlineInputBorder(borderSide: BorderSide.none),
          enabledBorder: const OutlineInputBorder(borderSide: BorderSide.none),
          focusedBorder: const OutlineInputBorder(borderSide: BorderSide.none),
          errorBorder: const OutlineInputBorder(borderSide: BorderSide.none),
          focusedErrorBorder: const OutlineInputBorder(borderSide: BorderSide.none),
          
          // نص الخطأ يظهر تحت الحقل مباشرة بخط كيرو وبشكل منبثق وأنيق دون دفع الفيلد الرمادي
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
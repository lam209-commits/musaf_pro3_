import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:math';
import '../../services/auth_service.dart';
import '../../services/email_service.dart';

// 🚀 تم إضافة استدعاء الزر المخصص الموحد هنا
import 'package:musaf_pro/widgets/custom_button.dart';

class PatientRegisterScreen extends StatefulWidget {
  const PatientRegisterScreen({super.key});

  @override
  State<PatientRegisterScreen> createState() => _PatientRegisterScreenState();
}

class _PatientRegisterScreenState extends State<PatientRegisterScreen> {
  final AuthService _auth = AuthService();

  // حقول المريض الأساسية
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _passController = TextEditingController();
  final _confirmPassController = TextEditingController();

  // حقول ربط المرافق
  final _caregiverEmailController = TextEditingController();
  String? _selectedRelation;

  bool _isLoading = false;
  final Color primaryRed = const Color(0xFFB7131A);

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
        title: const Text(
          'تسجيل مريض جديد',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 25.0),
        child: Column(
          children: [
            const SizedBox(height: 10),
            _buildFieldLabel("الاسم الكامل", Icons.person_outline),
            _buildCustomTextField(_nameController, "الاسم الثلاثي"),

            const SizedBox(height: 15),
            _buildFieldLabel("رقم الجوال", Icons.phone_android_outlined),
            _buildCustomTextField(
              _phoneController,
              "+966 5X XXX XXXX",
              isNumber: true,
            ),

            const SizedBox(height: 15),
            _buildFieldLabel("البريد الإلكتروني", Icons.email_outlined),
            _buildCustomTextField(_emailController, "patient@mail.com"),

            const SizedBox(height: 15),
            _buildFieldLabel(
              "بريد المرافق (لإرسال الكود)",
              Icons.alternate_email_rounded,
            ),
            _buildCustomTextField(
              _caregiverEmailController,
              "caregiver@mail.com",
            ),

            const SizedBox(height: 15),
            _buildFieldLabel("صلة القرابة للمرافق", Icons.people_outline),
            _buildDropdownField(),

            const SizedBox(height: 15),
            _buildFieldLabel("كلمة المرور", Icons.lock_outline),
            _buildCustomTextField(_passController, "........", isPass: true),

            const SizedBox(height: 15),
            _buildFieldLabel("تأكيد كلمة المرور", Icons.lock_reset_outlined),
            _buildCustomTextField(
              _confirmPassController,
              "........",
              isPass: true,
            ),

            const SizedBox(height: 40),

            // 🚀 التعديل هنا: استخدام الزر المخصص الموحد مع الحفاظ التام على حالة التحميل
            _isLoading
                ? CircularProgressIndicator(color: primaryRed)
                : CustomButton(
                    text: 'إنشاء حساب ومتابعة',
                    isPrimary: true, // زر أساسي أحمر
                    onPressed: _handlePatientRegister,
                  ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  // ✅ الدالة المحدثة والمحمية بالكامل من التعليق لأي سبب كان (بقت كما هي تماماً)
  void _handlePatientRegister() async {
    if (_emailController.text.isEmpty ||
        _passController.text.isEmpty ||
        _caregiverEmailController.text.isEmpty) {
      _showError('يرجى ملء جميع الحقول الأساسية وبريد المرافق');
      return;
    }

    if (_passController.text != _confirmPassController.text) {
      _showError('كلمات المرور غير متطابقة');
      return;
    }

    setState(() => _isLoading = true);

    try {
      String enteredEmail = _emailController.text.trim();
      debugPrint("🔵 بدأ تسجيل المريض في Auth...");

      // ✅ الاستدعاء الصحيح
var user = await _auth.registerUser(
  email: enteredEmail,
  password: _passController.text.trim(),
  displayName: _nameController.text.trim(), // تأكدي أن هذا هو اسم متغير حقل الاسم لديكِ
  phoneNumber: _phoneController.text.trim(), // تأكدي أن هذا هو اسم متغير حقل الجوال لديكِ
  role: 'patient', // تسجيل الحساب كمريض
);

      if (user != null) {
        // توليد الكود العشوائي للمطابقة
        String generatedCode = (Random().nextInt(9000) + 1000).toString();

        Map<String, dynamic> userData = {
          'uid': user.uid,
          'displayName': _nameController.text.trim(),
          'phoneNumber': _phoneController.text.trim(),
          'role': 'patient',
          'email': enteredEmail,
          'caregiverEmail': _caregiverEmailController.text.trim(),
          'relation': _selectedRelation,
          'pairingCode': generatedCode,
          'isCaregiverVerified': false,
          'createdAt': FieldValue.serverTimestamp(),
        };

        debugPrint("🔵 جاري حفظ بيانات المريض في Firestore...");
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .set(userData);

        debugPrint(
          "🔵 تم الحفظ بنجاح! جاري محاولة إرسال الإيميل بشكل مستقل...",
        );

        // 🚀 عزلنا الإيميل تماماً هنا عشان لو فشل ما يخرب التنقل للمستخدم
        try {
          await EmailService.sendPairingCode(
            toEmail: _caregiverEmailController.text.trim(),
            pairingCode: generatedCode,
          );
        } catch (emailError) {
          debugPrint(
            "⚠️ تم تجاوز خطأ إرسال الإيميل لضمان استمرار التطبيق: $emailError",
          );
        }

        // 🚀 النقل الفوري لصفحة الكود (غصب عن أي خطأ يحصل بالإيميل)
        if (mounted) {
          Navigator.pushReplacementNamed(context, '/pairing');
        }
      }
    } catch (e) {
      _showError('تنبيه: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Widget _buildFieldLabel(String label, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
          const SizedBox(width: 8),
          Icon(icon, size: 18, color: Colors.grey[600]),
        ],
      ),
    );
  }

  Widget _buildCustomTextField(
    TextEditingController ctrl,
    String hint, {
    bool isPass = false,
    bool isNumber = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: TextField(
        controller: ctrl,
        obscureText: isPass,
        textAlign: TextAlign.right,
        keyboardType: isNumber
            ? TextInputType.phone
            : TextInputType.emailAddress,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: Colors.grey[400], fontSize: 13),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.all(15),
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
          hint: const Text('اختر صلة القرابة', textAlign: TextAlign.right),
          items: [
            'أب/أم',
            'ابن/ابنة',
            'أخ/أخت',
            'زوج/زوجة',
            'أخرى',
          ].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
          onChanged: (val) => setState(() => _selectedRelation = val),
        ),
      ),
    );
  }
}

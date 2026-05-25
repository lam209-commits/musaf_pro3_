import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/auth_service.dart';

// 🚀 استدعاء الزر المخصص الموحد
import 'package:musaf_pro/widgets/custom_button.dart';

class CaregiverRegisterScreen extends StatefulWidget {
  const CaregiverRegisterScreen({super.key});

  @override
  State<CaregiverRegisterScreen> createState() =>
      _CaregiverRegisterScreenState();
}

class _CaregiverRegisterScreenState extends State<CaregiverRegisterScreen> {
  final AuthService _auth = AuthService();

  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _passController = TextEditingController();
  final _confirmPassController = TextEditingController();

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
          'تسجيل مرافق',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontFamily: 'Cairo'),
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
            _buildCustomTextField(_emailController, "example@mail.com"),

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

            _isLoading
                ? CircularProgressIndicator(color: primaryRed)
                : CustomButton(
                    text: 'إنشاء حساب مرافق',
                    isPrimary: true, 
                    backgroundColor: primaryRed,
                    onPressed: _handleCaregiverRegister,
                  ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  void _handleCaregiverRegister() async {
    if (_nameController.text.trim().isEmpty || 
        _phoneController.text.trim().isEmpty || 
        _emailController.text.trim().isEmpty || 
        _passController.text.trim().isEmpty) {
      _showError('يرجى ملء جميع البيانات الأساسية ⚠️');
      return;
    }

    if (_passController.text != _confirmPassController.text) {
      _showError('كلمات المرور غير متطابقة ⚠️');
      return;
    }

    setState(() => _isLoading = true);

    try {
      String enteredEmail = _emailController.text.trim();
      String? linkedPatientId;

      debugPrint("🔵 المرافق يحاول التسجيل... جاري فحص السيرفر");

      // 1. درع الحماية: هل يوجد مريض أضاف هذا الإيميل؟
      var patientQuery = await FirebaseFirestore.instance
          .collection('users')
          .where('caregiverEmail', isEqualTo: enteredEmail)
          .get(const GetOptions(source: Source.server));

      if (patientQuery.docs.isEmpty) {
        _showError(
          '❌ هذا البريد غير مصرح له! يجب أن يضيفك المريض أولاً في حسابه.',
        );
        setState(() => _isLoading = false);
        return; // الطرد ومنع التسجيل
      } else {
        // ✅ نجح التفتيش! تم إيجاد المريض
        linkedPatientId = patientQuery.docs.first.id;
        debugPrint("🔵 تم العثور على المريض! ID: $linkedPatientId");
      }

      // 🚀 2. الإصلاح: تمرير القيم الحقيقية من الحقول (Controllers) إلى الدالة
      var user = await _auth.registerUser(
        email: enteredEmail,
        password: _passController.text.trim(),
        displayName: _nameController.text.trim(),
        phoneNumber: _phoneController.text.trim(),
        role: 'caregiver',
      );

      if (user != null) {
        // 3. نقوم فقط بتحديث حقل الربط (linkedPatientId) لأن حساب المرافق تم إنشاؤه بالفعل في دالة registerUser
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .update({
          'linkedPatientId': linkedPatientId, 
        });
        
        debugPrint("🔵 تم حفظ المرافق وربطه بنجاح!");

        if (mounted) Navigator.pushReplacementNamed(context, '/caregiver_home');
      }
    } catch (e) {
      debugPrint("🔴 خطأ برمجي: $e");
      _showError('تنبيه: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg, style: const TextStyle(fontFamily: 'Cairo'))));
  }

  Widget _buildFieldLabel(String label, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, fontFamily: 'Cairo'),
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
        style: const TextStyle(fontFamily: 'Cairo', fontSize: 14),
        keyboardType: isNumber
            ? TextInputType.phone
            : TextInputType.emailAddress,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: Colors.grey[400], fontSize: 13, fontFamily: 'Cairo'),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.all(15),
        ),
      ),
    );
  }
}
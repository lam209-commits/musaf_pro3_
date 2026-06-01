import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:musaf_pro/core/theme/app_colors.dart';
import '../../domain/repositories/auth_repository.dart';

class DeleteAccountDialog extends StatefulWidget {
  final AuthRepository authRepository;

  const DeleteAccountDialog({super.key, required this.authRepository});

  @override
  State<DeleteAccountDialog> createState() => _DeleteAccountDialogState();
}

class _DeleteAccountDialogState extends State<DeleteAccountDialog> {
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscureText = true;
  String? _errorMessage;

  Future<void> _handleDelete() async {
  final password = _passwordController.text.trim();
  if (password.isEmpty) {
    setState(() => _errorMessage = "يرجى إدخال كلمة المرور الحالية");
    return;
  }

  setState(() {
    _isLoading = true;
    _errorMessage = null;
  });

  try {
    // 1. التحقق من وجود مريض مرتبط (يفضل جلب البيانات من الـ Repository)
    // نفترض أن الـ Repository يوفر دالة لجلب حالة الارتباط أو يمكنك جلبها مباشرة من Firestore
    final user = FirebaseAuth.instance.currentUser;
    final doc = await FirebaseFirestore.instance.collection('users').doc(user?.uid).get();
    final String? linkedPatientId = doc.data()?['linkedPatientId'];

    // 2. إذا كان مرتبطاً، نعرض تنبيهاً إضافياً (أو نعتمد على المنطق البرمجي)
    // إذا كنتِ تريدين التنبيه فقط:
    if (linkedPatientId != null && linkedPatientId.isNotEmpty) {
      // هنا يمكنك إما إيقاف الحذف أو متابعة الحذف مع تنبيه:
      // "تنبيه: أنت مرتبط حالياً بمريض، سيتم إلغاء الارتباط وحذف حسابك نهائياً"
    }

    // 3. التنفيذ
    await widget.authRepository.deleteUserAccountSecurely(password);

    if (mounted) {
      Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
    }
  } catch (e) {
    if (mounted) {
      setState(() => _errorMessage = e.toString().replaceAll("Exception: ", ""));
    }
  } finally {
    if (mounted) setState(() => _isLoading = false);
  }
}
  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Row(
        children: [
          Icon(Icons.warning_rounded, color:  AppColors.error, size: 28),
          SizedBox(width: 10),
          Text("حذف الحساب نهائياً", style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 18, color: Colors.red)),
        ],
      ),
content: Column(
  mainAxisSize: MainAxisSize.min,
  crossAxisAlignment: CrossAxisAlignment.start,
  children: [
    const Text(
      "هذا الإجراء لا يمكن التراجع عنه. سيتم مسح كافة بياناتك نهائياً.",
      style: TextStyle(fontFamily: 'Cairo', fontSize: 13, height: 1.5),
    ),
    const SizedBox(height: 10),
    
    // 🚀 جلب اسم المريض ديناميكياً
   FutureBuilder<DocumentSnapshot?>(
  future: _getLinkedPatientData(), // 👈 استدعاء اسم الدالة فقط
  builder: (context, snapshot) {
    if (snapshot.connectionState == ConnectionState.waiting) {
      return const SizedBox.shrink(); // أو CircularProgressIndicator()
    }
    
    if (snapshot.hasData && snapshot.data != null && snapshot.data!.exists) {
      final patientData = snapshot.data!.data() as Map<String, dynamic>;
      final String patientName = patientData['displayName'] ?? "التابع";
      
    return Padding(
  padding: const EdgeInsets.only(top: 5),
  // 1. استخدام Directionality لفرض اتجاه النص من اليمين لليسار
  child: Directionality(
    textDirection: TextDirection.rtl,
    child: Text(
      // 2. تعديل الصياغة لضمان انسيابية النص
      "تنبيه: أنت مرتبط حالياً با '$patientName'، سيتم فك الارتباط تلقائياً عند حذف الحساب.",
      style: const TextStyle(
        fontFamily: 'Cairo',
        fontSize: 13,
        color: AppColors.error,
        fontWeight: FontWeight.bold,
      ),
    ),
  ),
);
    }
    return const SizedBox.shrink();
  },
),
    
    const SizedBox(height: 15),
          TextField(
            controller: _passwordController,
            obscureText: _obscureText,
            decoration: InputDecoration(
              hintText: "كلمة المرور الحالية",
              hintStyle: const TextStyle(fontFamily: 'Cairo', fontSize: 13),
              errorText: _errorMessage,
              errorStyle: const TextStyle(fontFamily: 'Cairo'),
              filled: true,
              fillColor: Colors.grey[100],
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
              suffixIcon: IconButton(
                icon: Icon(_obscureText ? Icons.visibility_off : Icons.visibility, color: Colors.grey, size: 20),
                onPressed: () => setState(() => _obscureText = !_obscureText),
              ),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.pop(context),
          child: const Text("إلغاء", style: TextStyle(fontFamily: 'Cairo', color: Colors.grey, fontWeight: FontWeight.bold)),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _handleDelete,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          child: _isLoading
              ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : const Text("تأكيد الحذف", style: TextStyle(fontFamily: 'Cairo', color: Colors.white, fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }
  Future<DocumentSnapshot?> _getLinkedPatientData() async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return null;

  // جلب بيانات المرافق
  final caregiverDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
  if (!caregiverDoc.exists) return null;

  final data = caregiverDoc.data() as Map<String, dynamic>?;
  final String? patientId = data?['linkedPatientId'];

  if (patientId == null || patientId.isEmpty) return null;

  // جلب بيانات المريض
  return await FirebaseFirestore.instance.collection('users').doc(patientId).get();
}
}
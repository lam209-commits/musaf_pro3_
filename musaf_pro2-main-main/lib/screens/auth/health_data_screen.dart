import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

// 🚀 استدعاء الزر المخصص
import 'package:musaf_pro/widgets/custom_button.dart';

class HealthDataScreen extends StatefulWidget {
  const HealthDataScreen({super.key});

  @override
  State<HealthDataScreen> createState() => _HealthDataScreenState();
}

class _HealthDataScreenState extends State<HealthDataScreen> {
  // القوائم والبيانات
  String? _selectedGender;
  String? _selectedBloodType;
  final TextEditingController _ageController = TextEditingController();
  final TextEditingController _dobController = TextEditingController(); 
  final TextEditingController _emergencyContactController = TextEditingController(); // 📞 متحكم رقم الطوارئ المجلوب

  // لون مُسعف الملكي
  Color musafRed = const Color(0xFFB7131A);

  // متغيرات التاريخ المرضي
  String _chronicDiseases = "";
  String _currentMedications = "";
  String _allergies = "";
  String _caregiverId = ""; // لتخزين معرف المرافق المرتبط

  bool _isLoading = false;
  bool _isFetchingContact = true; // حالة تحميل جلب رقم المرافق

  @override
  void initState() {
    super.initState();
    _fetchCaregiverPhoneNumber(); // 🔄 جلب رقم المرافق فور فتح الشاشة
  }

  @override
  void dispose() {
    _ageController.dispose();
    _dobController.dispose();
    _emergencyContactController.dispose();
    super.dispose();
  }

  // 🔄 دالة جلب رقم هاتف المرافق تلقائياً من بياناته
  Future<void> _fetchCaregiverPhoneNumber() async {
    try {
      User? currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null) {
        // 1. جلب بيانات المريض الحالي لمعرفة من هو مرافقه (caregiverId)
        DocumentSnapshot userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(currentUser.uid)
            .get();

        if (userDoc.exists && userDoc.data() != null) {
          Map<String, dynamic> userData = userDoc.data() as Map<String, dynamic>;
          
          // نترض أنك تخزن معرف المرافق في حقل اسمه 'caregiverId' عند إنشاء حساب المريض
          _caregiverId = userData['caregiverId'] ?? ''; 

          if (_caregiverId.isNotEmpty) {
            // 2. جلب رقم هاتف المرافق من مجموعة المستخدمين باستخدام معرفه
            DocumentSnapshot caregiverDoc = await FirebaseFirestore.instance
                .collection('users')
                .doc(_caregiverId)
                .get();

            if (caregiverDoc.exists && caregiverDoc.data() != null) {
              Map<String, dynamic> caregiverData = caregiverDoc.data() as Map<String, dynamic>;
              
              setState(() {
                // نضع رقم المرافق داخل حقل النص المخصص للطوارئ
                _emergencyContactController.text = caregiverData['phone'] ?? 'لا يوجد رقم مسجل';
              });
            }
          } else {
            // في حال لم يكن له مرافق مرتبط (تسجيل مستقل مثلاً)
            _emergencyContactController.text = "لم يتم ربط مرافق بعد";
          }
        }
      }
    } catch (e) {
      debugPrint("Error fetching caregiver phone: $e");
      _emergencyContactController.text = "خطأ في تحميل الرقم";
    } finally {
      setState(() => _isFetchingContact = false);
    }
  }

  // ⏱️ دالة القيود الذكية للعمر
  void _validateAge(String value) {
    if (value.isEmpty) return;
    int? age = int.tryParse(value);
    if (age == null) return;

    if (value.length == 3) {
      if (!value.startsWith('1')) {
        _ageController.text = value.substring(0, 2);
        _ageController.selection = TextSelection.fromPosition(
          TextPosition(offset: _ageController.text.length),
        );
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('عذراً، يرجى إدخال عمر صحيح ⚠️', style: TextStyle(fontFamily: 'Cairo'))),
        );
      }
    }
  }

  // 📅 دالة اختيار تاريخ الميلاد وحساب العمر
  Future<void> _selectDateOfBirth() async {
    DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: DateTime(2000),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(primary: musafRed, onPrimary: Colors.white, onSurface: Colors.black87),
          ),
          child: child!,
        );
      },
    );

    if (pickedDate != null) {
      int calculatedAge = DateTime.now().year - pickedDate.year;
      if (DateTime.now().month < pickedDate.month || 
          (DateTime.now().month == pickedDate.month && DateTime.now().day < pickedDate.day)) {
        calculatedAge--;
      }

      setState(() {
        _dobController.text = DateFormat('yyyy-MM-dd').format(pickedDate);
        _ageController.text = calculatedAge.toString(); 
      });
    }
  }

  // دالة الحفظ النهائي
  void _saveHealthData() async {
    if (_selectedGender == null ||
        _selectedBloodType == null ||
        _ageController.text.isEmpty ||
        _dobController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى إكمال البيانات الأساسية وتاريخ الميلاد ⚠️', style: TextStyle(fontFamily: 'Cairo'))),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      String userId = FirebaseAuth.instance.currentUser!.uid;
      await FirebaseFirestore.instance.collection('users').doc(userId).update({
        'gender': _selectedGender,
        'age': _ageController.text,
        'birthDate': _dobController.text,
        'bloodType': _selectedBloodType,
        'chronicDiseases': _chronicDiseases,
        'currentMedications': _currentMedications,
        'allergies': _allergies,
        'emergencyContact': _emergencyContactController.text, // حفظ رقم المرافق المجلوب تلقائياً كطوارئ
        'setupComplete': true, 
      });

      if (mounted) {
        Navigator.pushReplacementNamed(context, '/patient_home');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ في الحفظ: $e', style: const TextStyle(fontFamily: 'Cairo'))));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB), 
      appBar: AppBar(
        title: const Text(
          'إدخال البيانات الحيوية',
          style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontFamily: 'Cairo'),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end, 
          children: [
            _buildInfoAlert(musafRed),
            const SizedBox(height: 25),

            _buildSectionHeader('البيانات الأساسية', Icons.person_outline),
            const SizedBox(height: 15),
            
            _buildReadOnlyTextField(
              _dobController, 
              'تاريخ الميلاد', 
              'اختر تاريخ ميلادك', 
              Icons.calendar_month_outlined,
              _selectDateOfBirth
            ),
            const SizedBox(height: 15),

            Row(
              children: [
                Expanded(child: _buildAgeTextField(_ageController, 'العمر', 'مثال: 25')),
                const SizedBox(width: 15),
                Expanded(
                  child: _buildDropdown(
                    'الجنس',
                    ['ذكر', 'أنثى'],
                    _selectedGender,
                    (val) => setState(() => _selectedGender = val),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 15),
            _buildDropdown(
              'فصيلة الدم',
              ['A+', 'A-', 'B+', 'B-', 'O+', 'O-', 'AB+', 'AB-'],
              _selectedBloodType,
              (val) => setState(() => _selectedBloodType = val),
              isRed: true,
              brandedRed: musafRed,
            ),

            const SizedBox(height: 30),

            _buildSectionHeader('التاريخ المرضي وطوارئ المرافق', Icons.history),
            const SizedBox(height: 15),
            
            // 📞 حقل رقم الطوارئ المجلوب تلقائياً من بيانات المرافق (عرض فقط لعدم التعديل بالخطأ)
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                const Text('رقم هاتف المرافق (للطوارئ تلقائياً)', style: TextStyle(fontSize: 14, color: Colors.grey, fontFamily: 'Cairo')),
                const SizedBox(height: 8),
                TextField(
                  controller: _emergencyContactController,
                  readOnly: true, // 🔒 للقراءة فقط لمنع العبث بالرقم المجلوب من الحساب الأساسي
                  textAlign: TextAlign.right,
                  style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: Colors.grey.shade200, // تمييزه بلون رمادي خفيف لأنه غير قابل للتعديل
                    prefixIcon: _isFetchingContact 
                        ? const Padding(
                            padding: EdgeInsets.all(12.0),
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.grey),
                          )
                        : Icon(Icons.contact_phone, color: musafRed),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 15),

            _buildExpansionStep('هل تعاني من أمراض مزمنة؟', Icons.monitor_heart_outlined, (val) => _chronicDiseases = val, musafRed),
            _buildExpansionStep('هل تتناول أدوية حالياً؟', Icons.medication_outlined, (val) => _currentMedications = val, musafRed),
            _buildExpansionStep('هل لديك أي حساسيات؟', Icons.warning_amber_rounded, (val) => _allergies = val, musafRed),

            const SizedBox(height: 40),

            _isLoading
                ? Center(child: CircularProgressIndicator(color: musafRed))
                : CustomButton(
                    text: 'حفظ الملف الطبي',
                    isPrimary: true,
                    backgroundColor: musafRed,
                    onPressed: _saveHealthData,
                  ),
          ],
        ),
      ),
    );
  }

  // --- عناصر الواجهة المخصصة ---

  Widget _buildInfoAlert(Color alertColor) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: alertColor.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: alertColor.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: alertColor),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'هذه المعلومات ورقم هاتف مرافقك ستكون متاحة للمسعفين فور طلبك للنجدة لضمان سلامتك الفورية.',
              textAlign: TextAlign.right,
              style: TextStyle(fontSize: 13, color: alertColor, fontFamily: 'Cairo'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey, fontFamily: 'Cairo')),
        const SizedBox(width: 8),
        Icon(icon, size: 20, color: Colors.grey),
      ],
    );
  }

  Widget _buildAgeTextField(TextEditingController ctrl, String label, String hint) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(label, style: const TextStyle(fontSize: 14, color: Colors.grey, fontFamily: 'Cairo')),
        const SizedBox(height: 8),
        TextField(
          controller: ctrl,
          textAlign: TextAlign.right,
          keyboardType: TextInputType.number,
          onChanged: _validateAge,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(3)],
          decoration: InputDecoration(
            hintText: hint,
            filled: true,
            fillColor: Colors.white,
            hintStyle: const TextStyle(fontFamily: 'Cairo', fontSize: 13),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          ),
        ),
      ],
    );
  }

  Widget _buildReadOnlyTextField(TextEditingController ctrl, String label, String hint, IconData icon, VoidCallback onTap) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(label, style: const TextStyle(fontSize: 14, color: Colors.grey, fontFamily: 'Cairo')),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: onTap,
          child: AbsorbPointer(
            child: TextField(
              controller: ctrl,
              textAlign: TextAlign.right,
              decoration: InputDecoration(
                hintText: hint,
                filled: true,
                prefixIcon: Icon(icon, color: musafRed),
                fillColor: Colors.white,
                hintStyle: const TextStyle(fontFamily: 'Cairo', fontSize: 13),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDropdown(String label, List<String> items, String? currentVal, Function(String?) onChange, {bool isRed = false, Color brandedRed = Colors.red}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(label, style: const TextStyle(fontSize: 14, color: Colors.grey, fontFamily: 'Cairo')),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: isRed && currentVal == null ? brandedRed.withOpacity(0.05) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: isRed && currentVal == null ? Border.all(color: brandedRed.withOpacity(0.2)) : null,
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: currentVal,
              isExpanded: true,
              hint: const Text('اختر', style: TextStyle(fontFamily: 'Cairo', fontSize: 13)),
              items: items.map((e) => DropdownMenuItem(value: e, child: Text(e, style: const TextStyle(fontFamily: 'Cairo')))).toList(),
              onChanged: onChange,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildExpansionStep(String title, IconData icon, Function(String) onTyped, Color tileRed) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ExpansionTile(
        leading: Icon(icon, color: tileRed),
        title: Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500, fontFamily: 'Cairo')),
        children: [
          Padding(
            padding: const EdgeInsets.all(15.0),
            child: TextField(
              onChanged: onTyped,
              maxLines: 2,
              textAlign: TextAlign.right,
              decoration: const InputDecoration(
                hintText: 'اكتب التفاصيل هنا...',
                hintStyle: TextStyle(fontFamily: 'Cairo', fontSize: 13),
                border: InputBorder.none,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
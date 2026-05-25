import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';

// تم تغيير الاسم هنا ليكون خاصاً بالمرافق
class CaregiverSettingsScreen extends StatefulWidget {
  final String? caregiverId;
  const CaregiverSettingsScreen({super.key, this.caregiverId});

  @override
  State<CaregiverSettingsScreen> createState() => _CaregiverSettingsScreenState();
}

class _CaregiverSettingsScreenState extends State<CaregiverSettingsScreen> {
  final String? currentUserId = FirebaseAuth.instance.currentUser?.uid;
  String caregiverName = "المرافق";
  String caregiverEmail = "جاري التحميل...";
  String caregiverPhone = "جاري التحميل..."; 
  String currentPatientId = ""; 
  String caregiverImageUrl = ""; 
  bool isLoading = true;

  bool medAlertsEnabled = true;
  bool zoneAlertsEnabled = true;
  bool soundAndVibrationEnabled = true;

  final Color themeColor = const Color(0xFF2E7D32); 

  @override
  void initState() {
    super.initState();
    _loadCaregiverData();
  }

  Future<void> _loadCaregiverData() async {
    final uid = widget.caregiverId ?? FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      try {
        var userDoc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
        if (userDoc.exists && mounted) {
          setState(() {
            caregiverName = userDoc.data()?['displayName'] ?? "المرافق";
            caregiverEmail = userDoc.data()?['email']?.toString().trim() ?? "لا يوجد بريد إلكتروني مسجل";
            caregiverPhone = userDoc.data()?['phoneNumber']?.toString().trim() ?? "لا يوجد رقم هاتف مسجل";
            caregiverImageUrl = userDoc.data()?['profileImageUrl'] ?? "";
            currentPatientId = userDoc.data()?['linkedPatientId'] ?? "";
            isLoading = false;
          });
        }
      } catch (e) {
        if (mounted) setState(() => isLoading = false);
      }
    }
  }

  Future<void> _pickAndUploadProfileImage() async {
    final ImagePicker picker = ImagePicker();
    try {
      final XFile? pickedFile = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
      if (pickedFile != null && currentUserId != null) {
        setState(() => caregiverImageUrl = pickedFile.path);
        await FirebaseFirestore.instance.collection('users').doc(currentUserId).update({'profileImageUrl': pickedFile.path});
      }
    } catch (e) {
      debugPrint("خطأ أثناء اختيار الصورة: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Scaffold(backgroundColor: const Color(0xFFF8F9FD), body: Center(child: CircularProgressIndicator(color: themeColor)));
    }

    ImageProvider? profileImageProvider = caregiverImageUrl.isNotEmpty
        ? (caregiverImageUrl.startsWith('http') ? NetworkImage(caregiverImageUrl) : FileImage(File(caregiverImageUrl)))
        : null;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FD),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF8F9FD),
        elevation: 0,
        centerTitle: true,
        title: const Text("إدارة التطبيق", style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, color: Colors.black87, fontSize: 20)),
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          children: [
            // صورة الملف الشخصي
            Center(
              child: Stack(
                children: [
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: themeColor.withOpacity(0.3), width: 2)),
                    child: CircleAvatar(
                      radius: 45, backgroundColor: Colors.white,
                      backgroundImage: profileImageProvider,
                      child: profileImageProvider == null ? Icon(Icons.person, size: 45, color: themeColor) : null,
                    ),
                  ),
                  Positioned(
                    bottom: 0, left: 0,
                    child: GestureDetector(
                      onTap: _pickAndUploadProfileImage,
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(color: themeColor, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2)),
                        child: const Icon(Icons.camera_alt_rounded, size: 16, color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 30),

            // 1. الحساب
            _buildSectionTitle("الحساب"),
            _buildSettingsGroup([
              _buildSettingsTile(
                Icons.person_outline, 
                "تعديل البيانات", 
                onTap: () => _showEditProfileDialog()
              ),
              _buildDivider(),
              _buildSettingsTile(
                Icons.lock_outline_rounded, 
                "تغيير كلمة المرور", 
                onTap: () => _showPasswordResetDialog()
              ),
              _buildDivider(),
              _buildSettingsTile(
                Icons.groups_outlined, 
                "إدارة المرضى", 
                onTap: () => _showManagePatientsDialog()
              ),
            ]),

            // 2. الإشعارات
            _buildSectionTitle("الإشعارات"),
            _buildSettingsGroup([
              _buildSwitchTile(Icons.medication_outlined, "تنبيهات الدواء", medAlertsEnabled, (val) => setState(() => medAlertsEnabled = val)),
              _buildDivider(),
              _buildSwitchTile(Icons.share_location_outlined, "تنبيهات الخروج والدخول من المنطقة", zoneAlertsEnabled, (val) => setState(() => zoneAlertsEnabled = val)),
            ]),

            // 3. الدعم
            _buildSectionTitle("الدعم"),
            _buildSettingsGroup([
              _buildSettingsTile(
                Icons.headset_mic_outlined, 
                "تواصل معنا", 
                onTap: () {
                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      title: const Text(
                        "تواصل معنا", 
                        style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold), 
                        textAlign: TextAlign.center
                      ),
                      content: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.support_agent_rounded, size: 60, color: Color(0xFF2E7D32)),
                          const SizedBox(height: 15),
                          const Text(
                            "نسعد بخدمتكم عبر الرقم التالي:", 
                            style: TextStyle(fontFamily: 'Cairo', fontSize: 14), 
                            textAlign: TextAlign.center
                          ),
                          const SizedBox(height: 15),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                            decoration: BoxDecoration(
                              color: const Color(0xFF2E7D32).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(15),
                            ),
                            child: const Text(
                              "774180199", // قم بتغيير الأصفار إلى رقمك الفعلي
                              style: TextStyle(fontFamily: 'Cairo', fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF2E7D32), letterSpacing: 2),
                              textDirection: TextDirection.ltr,
                            ),
                          ),
                        ],
                      ),
                      actions: [
                        Center(
                          child: TextButton(
                            onPressed: () => Navigator.pop(context), 
                            child: const Text("إغلاق", style: TextStyle(fontFamily: 'Cairo', color: Colors.grey, fontWeight: FontWeight.bold, fontSize: 16))
                          ),
                        )
                      ],
                    ),
                  );
                }
              ),
              _buildDivider(),
              _buildSettingsTile(
                Icons.privacy_tip_outlined, 
                "سياسة الخصوصية", 
                onTap: () {
                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      title: const Text("سياسة الخصوصية", style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
                      content: const SingleChildScrollView(
                        child: Text(
                          "نحن في تطبيق مُسعف نحرص على حماية بياناتك الشخصية والطبية. لا يتم مشاركة بيانات المواقع والتنبيهات الجغرافية إلا مع المرافقين المعتمدين من قبلك...\n", 
                          style: TextStyle(fontFamily: 'Cairo', fontSize: 14, height: 1.5)
                        ),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context), 
                          child: const Text("موافق", style: TextStyle(fontFamily: 'Cairo', color: Color(0xFF2E7D32), fontWeight: FontWeight.bold))
                        )
                      ],
                    ),
                  );
                }
              ),
              _buildDivider(),
              _buildSettingsTile(
                Icons.info_outline_rounded, 
                "عن التطبيق", 
                onTap: () {
                  showAboutDialog(
                    context: context,
                    applicationName: 'تطبيق مُسعف',
                    applicationVersion: '1.0.0',
                    applicationLegalese: '© 2026 جميع الحقوق محفوظة',
                    children: [
                      const SizedBox(height: 10),
                      const Text('تطبيق مُسعف لمتابعة المرضى والرعاية الصحية.', style: TextStyle(fontFamily: 'Cairo')),
                    ],
                  );
                }
              ),
            ]),

            // 4. تسجيل الخروج (مفصول عن الخطر)
            _buildSettingsGroup([
              _buildSettingsTile(Icons.logout_rounded, "تسجيل الخروج", onTap: () => _showLogoutDialog()),
            ]),

            // 5. منطقة الخطر (Danger Zone)
            _buildSectionTitle("منطقة الخطر", color: Colors.redAccent),
            Container(
              margin: const EdgeInsets.only(bottom: 25),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.red.withOpacity(0.2), width: 1.5), 
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))],
              ),
              child: Column(
                children: [
                  _buildSettingsTile(Icons.pause_circle_outline_rounded, "تعطيل الحساب مؤقتاً", color: Colors.orange[700], onTap: () {}),
                  const Divider(height: 1, indent: 50),
                  _buildSettingsTile(Icons.delete_forever_rounded, "حذف الحساب نهائياً", color: Colors.red, onTap: () => _handleDeleteRequest()),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  // ----------- الهيكلة البصرية -----------

  Widget _buildSectionTitle(String title, {Color color = Colors.black54}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, right: 10),
      child: Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, fontFamily: 'Cairo', color: color)),
    );
  }

  Widget _buildSettingsGroup(List<Widget> children) {
    return Container(
      margin: const EdgeInsets.only(bottom: 25),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(children: children),
    );
  }

  Widget _buildSettingsTile(IconData icon, String title, {Color? color, required VoidCallback onTap}) {
    Color iconColor = color ?? themeColor;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: iconColor.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
        child: Icon(icon, color: iconColor, size: 20),
      ),
      title: Text(title, style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 14, color: color ?? Colors.black87)),
      trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.black38),
      onTap: onTap,
    );
  }

  Widget _buildSwitchTile(IconData icon, String title, bool value, ValueChanged<bool> onChanged) {
    return SwitchListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      secondary: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: themeColor.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
        child: Icon(icon, color: themeColor, size: 20),
      ),
      title: Text(title, style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black87)),
      value: value,
      activeColor: themeColor,
      onChanged: onChanged,
    );
  }

  Widget _buildDivider() {
    return const Divider(height: 1, indent: 56, endIndent: 16, color: Color(0xFFEEEEEE));
  }

  // ----------- التدفق الآمن (Safe Flow) -----------

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (d) => AlertDialog(
        title: const Text("تأكيد تسجيل الخروج", style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold), textAlign: TextAlign.right),
        content: const Text("هل أنت متأكد من رغبتك في تسجيل الخروج؟", style: TextStyle(fontFamily: 'Cairo', fontSize: 14)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d), child: const Text("إلغاء", style: TextStyle(fontFamily: 'Cairo', color: Colors.grey))),
          TextButton(onPressed: () async { await FirebaseAuth.instance.signOut(); if (mounted) Navigator.pushNamedAndRemoveUntil(context, '/login', (r) => false); }, child: const Text("خروج", style: TextStyle(fontFamily: 'Cairo', color: Colors.red, fontWeight: FontWeight.bold)))
        ],
      )
    );
  }

  void _handleDeleteRequest() {
    if (currentPatientId.isNotEmpty) {
      _showCannotDeleteDialog();
    } else {
      _showDeleteWarningDialog();
    }
  }

  void _showCannotDeleteDialog() {
    showDialog(
      context: context,
      builder: (d) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 28),
            SizedBox(width: 10),
            Text("لا يمكن حذف الحساب", style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, color: Colors.orange, fontSize: 18)),
          ],
        ),
        content: const Text(
          "يوجد مريض مرتبط بحسابك حالياً.\nيجب نقل الإشراف إلى مرافق آخر أو إزالة الارتباط أولاً لضمان سلامة المريض واستمرار التنبيهات.", 
          style: TextStyle(fontFamily: 'Cairo', fontSize: 14, height: 1.5)
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: themeColor, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            onPressed: () => Navigator.pop(d), 
            child: const Text("حسناً، فهمت", style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, color: Colors.white))
          ),
        ],
      )
    );
  }

  void _showDeleteWarningDialog() {
    showDialog(
      context: context,
      builder: (d) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("هل أنت متأكد من الحذف؟", style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, color: Colors.red), textAlign: TextAlign.right),
        content: const Text(
          "سيتم:\n• حذف بياناتك بالكامل\n• إلغاء ارتباطك بأي مرضى\n• إيقاف جميع التنبيهات\n\nهذا الإجراء لا يمكن التراجع عنه.", 
          style: TextStyle(fontFamily: 'Cairo', fontSize: 14, height: 1.5)
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d), child: const Text("إلغاء", style: TextStyle(fontFamily: 'Cairo', color: Colors.grey, fontWeight: FontWeight.bold))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            onPressed: () {
              Navigator.pop(d);
              _executeDelete(); 
            }, 
            child: const Text("تأكيد الحذف", style: TextStyle(fontFamily: 'Cairo', color: Colors.white, fontWeight: FontWeight.bold))
          ),
        ],
      ),
    );
  }

  Future<void> _executeDelete() async {
    try {
      User? user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await FirebaseFirestore.instance.collection('users').doc(user.uid).delete();
        await user.delete();
        if (mounted) Navigator.pushNamedAndRemoveUntil(context, '/onboarding', (r) => false);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("يتطلب هذا الإجراء تسجيل الدخول حديثاً لأسباب أمنية.")));
    }
  }

  // --- النوافذ المنبثقة لقسم الحساب ---

  // 1. نافذة تعديل البيانات
  void _showEditProfileDialog() {
    TextEditingController nameController = TextEditingController(text: caregiverName);
    TextEditingController phoneController = TextEditingController(
      text: caregiverPhone != "لا يوجد رقم هاتف مسجل" ? caregiverPhone : ""
    );

    showDialog(
      context: context,
      builder: (d) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("تعديل البيانات", style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: InputDecoration(
                labelText: "الاسم",
                labelStyle: const TextStyle(fontFamily: 'Cairo'),
                focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: themeColor)),
              ),
            ),
            const SizedBox(height: 15),
            TextField(
              controller: phoneController,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                labelText: "رقم الهاتف",
                labelStyle: const TextStyle(fontFamily: 'Cairo'),
                focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: themeColor)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(d),
            child: const Text("إلغاء", style: TextStyle(fontFamily: 'Cairo', color: Colors.grey))
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: themeColor, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            onPressed: () async {
              if (nameController.text.isNotEmpty && currentUserId != null) {
                // حفظ في فايربيس
                await FirebaseFirestore.instance.collection('users').doc(currentUserId).update({
                  'displayName': nameController.text.trim(),
                  'phoneNumber': phoneController.text.trim(),
                });
                // تحديث الشاشة
                setState(() {
                  caregiverName = nameController.text.trim();
                  caregiverPhone = phoneController.text.trim().isEmpty ? "لا يوجد رقم هاتف مسجل" : phoneController.text.trim();
                });
                if (mounted) Navigator.pop(d);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("تم تحديث البيانات ✅", style: TextStyle(fontFamily: 'Cairo'))));
              }
            },
            child: const Text("حفظ", style: TextStyle(fontFamily: 'Cairo', color: Colors.white, fontWeight: FontWeight.bold))
          ),
        ],
      ),
    );
  }

  // 2. نافذة تأكيد تغيير كلمة المرور
  void _showPasswordResetDialog() {
    showDialog(
      context: context,
      builder: (d) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("تغيير كلمة المرور", style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
        content: const Text(
          "سيتم إرسال رابط إلى بريدك الإلكتروني لتعيين كلمة مرور جديدة. هل تود الاستمرار؟",
          style: TextStyle(fontFamily: 'Cairo', fontSize: 14, height: 1.5)
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(d),
            child: const Text("إلغاء", style: TextStyle(fontFamily: 'Cairo', color: Colors.grey))
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: themeColor, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            onPressed: () {
              Navigator.pop(d);
              if (caregiverEmail.isNotEmpty && caregiverEmail != "لا يوجد بريد إلكتروني مسجل" && !caregiverEmail.contains("جاري")) {
                FirebaseAuth.instance.sendPasswordResetEmail(email: caregiverEmail);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("تم إرسال الرابط إلى بريدك 📧", style: TextStyle(fontFamily: 'Cairo'))));
              } else {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("بريد إلكتروني غير صالح.", style: TextStyle(fontFamily: 'Cairo'))));
              }
            },
            child: const Text("إرسال الرابط", style: TextStyle(fontFamily: 'Cairo', color: Colors.white, fontWeight: FontWeight.bold))
          ),
        ],
      ),
    );
  }

  // 3. نافذة إدارة المرضى المبسطة
  void _showManagePatientsDialog() {
    bool hasPatient = currentPatientId.isNotEmpty;

    showDialog(
      context: context,
      builder: (d) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("إدارة المرضى", style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(hasPatient ? Icons.check_circle_outline_rounded : Icons.person_add_disabled_rounded, 
                 size: 60, color: hasPatient ? themeColor : Colors.grey),
            const SizedBox(height: 15),
            Text(
              hasPatient ? "لديك مريض مرتبط حالياً." : "لا يوجد مريض مرتبط بحسابك.",
              style: const TextStyle(fontFamily: 'Cairo', fontSize: 14),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(d),
            child: const Text("إغلاق", style: TextStyle(fontFamily: 'Cairo', color: Colors.grey))
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: hasPatient ? Colors.red : themeColor, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            onPressed: () {
              Navigator.pop(d);
              if (hasPatient) {
                 ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("تحتاج لفك الارتباط أولاً.", style: TextStyle(fontFamily: 'Cairo'))));
              } else {
                 ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("الرجاء إدخال كود المريض", style: TextStyle(fontFamily: 'Cairo'))));
              }
            },
            child: Text(hasPatient ? "فك الارتباط" : "إضافة مريض", style: const TextStyle(fontFamily: 'Cairo', color: Colors.white, fontWeight: FontWeight.bold))
          ),
        ],
      ),
    );
  }
}
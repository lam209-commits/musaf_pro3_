import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart'; // تمت إضافة هذه المكتبة لرفع الصور

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
  bool soundAndVibrationEnabled = true; // تمت الإضافة

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

  // تم التعديل: رفع الصورة إلى Firebase Storage بدل المسار المحلي
  Future<void> _pickAndUploadProfileImage() async {
    final ImagePicker picker = ImagePicker();
    try {
      final XFile? pickedFile = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
      if (pickedFile != null && currentUserId != null) {
        // إظهار حالة التحميل أثناء الرفع
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("جاري تحديث الصورة...", style: TextStyle(fontFamily: 'Cairo'))));
        
        File imageFile = File(pickedFile.path);
        
        // مسار الحفظ في Storage
        Reference storageRef = FirebaseStorage.instance.ref().child('profile_images').child('$currentUserId.jpg');
        
        // رفع الملف
        UploadTask uploadTask = storageRef.putFile(imageFile);
        TaskSnapshot snapshot = await uploadTask;
        
        // الحصول على الرابط السحابي
        String downloadUrl = await snapshot.ref.getDownloadURL();

        // تحديث الرابط في Firestore
        await FirebaseFirestore.instance.collection('users').doc(currentUserId).update({'profileImageUrl': downloadUrl});
        
        setState(() => caregiverImageUrl = downloadUrl);
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("تم تحديث الصورة بنجاح ✅", style: TextStyle(fontFamily: 'Cairo'))));
        }
      }
    } catch (e) {
      debugPrint("خطأ أثناء اختيار/رفع الصورة: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("حدث خطأ أثناء رفع الصورة", style: TextStyle(fontFamily: 'Cairo'))));
      }
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
        // التعديل 1: تغيير الاسم إلى الإعدادات
        title: const Text("الإعدادات", style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, color: Colors.black87, fontSize: 20)),
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
            const SizedBox(height: 15),
            
            // التعديل 2 & 9: عرض معلومات الحساب تحت الصورة
            Center(
              child: Column(
                children: [
                  Text(caregiverName, style: const TextStyle(fontFamily: 'Cairo', fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
                  const SizedBox(height: 4),
                  Text(caregiverEmail, style: TextStyle(fontFamily: 'Cairo', fontSize: 14, color: Colors.grey[600])),
                ],
              ),
            ),
            const SizedBox(height: 30),

            // التعديل 3 & 4: ترتيب قسم الحساب وتغيير المسميات
            _buildSectionTitle("الحساب"),
            _buildSettingsGroup([
              _buildSettingsTile(
                Icons.person_outline, 
                "الملف الشخصي", 
                onTap: () => _showEditProfileDialog()
              ),
              _buildDivider(),
              _buildSettingsTile(
                Icons.groups_outlined, 
                "إدارة المرضى", 
                onTap: () => _showManagePatientsDialog()
              ),
              _buildDivider(),
              _buildSettingsTile(
                Icons.lock_outline_rounded, 
                "الأمان وكلمة المرور", 
                onTap: () => _showPasswordResetDialog()
              ),
            ]),

            // التعديل 12: إضافة قسم الأجهزة المرتبطة
          // قسم الأجهزة المرتبطة (مفعل ديناميكياً 🚀)
            _buildSectionTitle("الأجهزة المرتبطة"),
            _buildSettingsGroup([
              currentPatientId.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Center(
                        child: Text("لا يوجد جهاز مرتبط حالياً.", 
                          style: TextStyle(fontFamily: 'Cairo', color: Colors.grey, fontWeight: FontWeight.bold)),
                      ),
                    )
                  : StreamBuilder<DocumentSnapshot>(
                      // نستمع لتحديثات ملف المريض بشكل حي
                      stream: FirebaseFirestore.instance.collection('users').doc(currentPatientId).snapshots(),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) {
                          return const Padding(
                            padding: EdgeInsets.all(16.0),
                            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                          );
                        }

                        var patientData = snapshot.data?.data() as Map<String, dynamic>?;
                        
                        // قراءة القيم من قاعدة البيانات (مع قيم افتراضية في حال عدم وجودها بعد)
                        int batteryLevel = patientData?['batteryLevel'] ?? 0;
                        bool isOnline = patientData?['isOnline'] ?? false;
                        Timestamp? lastUpdateTs = patientData?['lastLocationUpdate'];

                        // معالجة النصوص والألوان بناءً على الحالة
                        String statusText = isOnline ? "متصل" : "غير متصل";
                        Color statusColor = isOnline ? Colors.green : Colors.redAccent;
                        IconData statusIcon = isOnline ? Icons.check_circle_rounded : Icons.error_outline_rounded;
                        
                        // معالجة وقت آخر تحديث
                        String timeText = _getTimeAgo(lastUpdateTs);

                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          leading: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(color: themeColor.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                            child: Icon(Icons.smartphone_rounded, color: themeColor, size: 24),
                          ),
                          title: const Text("جهاز التابع", style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black87)),
                          // عرض البيانات الحية هنا 🚀
                          subtitle: Text(
                            "$statusText • بطارية $batteryLevel% • آخر تحديث $timeText", 
                            style: TextStyle(fontFamily: 'Cairo', fontSize: 12, color: statusColor)
                          ),
                          trailing: Icon(statusIcon, color: statusColor, size: 20),
                          onTap: () {
                            if (batteryLevel < 20) {
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                                content: Text(" بطارية جهاز التابع منخفضه.", style: TextStyle(fontFamily: 'Cairo')),
                                backgroundColor: Colors.orange,
                              ));
                            }
                          }, 
                        );
                      },
                    ),
            ]),

            // التعديل 5: إضافة خيار الصوت والاهتزاز للإشعارات
            _buildSectionTitle("الإشعارات"),
            _buildSettingsGroup([
              _buildSwitchTile(Icons.medication_outlined, "تنبيهات الدواء", medAlertsEnabled, (val) => setState(() => medAlertsEnabled = val)),
              _buildDivider(),
              _buildSwitchTile(Icons.share_location_outlined, "تنبيهات الخروج والدخول", zoneAlertsEnabled, (val) => setState(() => zoneAlertsEnabled = val)),
              _buildDivider(),
              _buildSwitchTile(Icons.vibration_rounded, "الصوت والاهتزاز", soundAndVibrationEnabled, (val) => setState(() => soundAndVibrationEnabled = val)),
            ]),

            // التعديل 6: ترتيب الدعم (تواصل معنا -> عن التطبيق -> سياسة الخصوصية)
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
                      title: const Text("تواصل معنا", style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                      content: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.support_agent_rounded, size: 60, color: Color(0xFF2E7D32)),
                          const SizedBox(height: 15),
                          const Text("نسعد بخدمتكم عبر الرقم التالي:", style: TextStyle(fontFamily: 'Cairo', fontSize: 14), textAlign: TextAlign.center),
                          const SizedBox(height: 15),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                            decoration: BoxDecoration(color: const Color(0xFF2E7D32).withOpacity(0.1), borderRadius: BorderRadius.circular(15)),
                            child: const Text("774180199", style: TextStyle(fontFamily: 'Cairo', fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF2E7D32), letterSpacing: 2), textDirection: TextDirection.ltr),
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
            ]),

            // التعديل 7: تسجيل الخروج بلون مميز
            _buildSettingsGroup([
              _buildSettingsTile(Icons.logout_rounded, "تسجيل الخروج", color: Colors.orange, onTap: () => _showLogoutDialog()),
            ]),

            // التعديل 8: مسافة أكبر لمنطقة الخطر
            const SizedBox(height: 25),
            _buildSectionTitle("منطقة الخطر", color: Colors.redAccent),
            Container(
              margin: const EdgeInsets.only(bottom: 40),
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
          "يوجد تابع مرتبط بحسابك حالياً.\nيجب نقل الإشراف إلى مرافق آخر أو إزالة الارتباط أولاً لضمان سلامة التابع واستمرار التنبيهات.", 
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
                await FirebaseFirestore.instance.collection('users').doc(currentUserId).update({
                  'displayName': nameController.text.trim(),
                  'phoneNumber': phoneController.text.trim(),
                });
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
            style: ElevatedButton.styleFrom(
              backgroundColor: themeColor, 
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))
            ),
            // 🚀 إضافة async لأن العملية تتطلب اتصال بالإنترنت (Firebase)
            onPressed: () async {
              Navigator.pop(d); // إغلاق النافذة
              
              if (caregiverEmail.isNotEmpty && caregiverEmail != "لا يوجد بريد إلكتروني مسجل" && !caregiverEmail.contains("جاري")) {
                try {
                  // 🚀 تفعيل الاتصال الحقيقي بـ Firebase لإرسال رابط إعادة التعيين
                  await FirebaseAuth.instance.sendPasswordResetEmail(email: caregiverEmail);
                  
                  // إظهار رسالة نجاح خضراء إذا تم الإرسال
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text("تم إرسال الرابط بنجاح! يرجى تفقد بريدك الإلكتروني 📧", style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
                        backgroundColor: Colors.green,
                      )
                    );
                  }
                } on FirebaseAuthException catch (e) {
                  // 🚀 التقاط أخطاء فايربيس (مثل عدم وجود إنترنت أو الإيميل محذوف)
                  String errorMsg = "حدث خطأ أثناء إرسال الرابط.";
                  if (e.code == 'user-not-found') {
                    errorMsg = "لا يوجد حساب مسجل بهذا البريد.";
                  } else if (e.code == 'network-request-failed') {
                    errorMsg = "تأكد من اتصالك بالإنترنت 📡.";
                  }
                  
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(errorMsg, style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
                        backgroundColor: Colors.red,
                      )
                    );
                  }
                }
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text("بريد إلكتروني غير صالح ⚠️", style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
                    backgroundColor: Colors.orange,
                  )
                );
              }
            },
            child: const Text("إرسال الرابط", style: TextStyle(fontFamily: 'Cairo', color: Colors.white, fontWeight: FontWeight.bold))
          ),
        ],
      ),
    );
  }

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
                 // 🚀 استدعاء نافذة التأكيد لفك الارتباط الفعلي
                 _confirmUnlinkPatient();
              } else {
                 // 🚀 توجيه المستخدم لصفحة إدخال كود الربط لإضافة مريض جديد
                 Navigator.pushNamed(context, '/pairing');
              }
            },
            child: Text(hasPatient ? "فك الارتباط" : "إضافة مريض", style: const TextStyle(fontFamily: 'Cairo', color: Colors.white, fontWeight: FontWeight.bold))
          ),
        ],
      ),
    );
  }

  // 🚀 دالة جديدة: تقوم بحذف الارتباط فعلياً من قاعدة البيانات (Firestore)
  void _confirmUnlinkPatient() {
    showDialog(
      context: context,
      builder: (d) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("تأكيد فك الارتباط", style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, color: Colors.red)),
        content: const Text("هل أنت متأكد أنك تريد فك ارتباطك بهذا التابع؟ لن تتلقى أي تنبيهات أو بيانات بعد الآن.", style: TextStyle(fontFamily: 'Cairo', fontSize: 14, height: 1.5)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(d), 
            child: const Text("إلغاء", style: TextStyle(fontFamily: 'Cairo', color: Colors.grey))
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            onPressed: () async {
              Navigator.pop(d);
              if (currentUserId != null) {
                // 1. مسح الارتباط من قاعدة البيانات
                await FirebaseFirestore.instance.collection('users').doc(currentUserId).update({
                  'linkedPatientId': '',
                  'linkedPatientName': FieldValue.delete(), // حذف الاسم إن وجد
                });
                
                // 2. تحديث الشاشة محلياً
                setState(() {
                  currentPatientId = "";
                });
                
                // 3. عرض رسالة النجاح
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text("تم فك الارتباط بنجاح ✅", style: TextStyle(fontFamily: 'Cairo')),
                    backgroundColor: Colors.green,
                  ));
                  
                  // إعادة التوجيه للوحة التحكم لتفعيل حاجز الأمان وإجباره على ربط مريض جديد
                  Navigator.pushReplacementNamed(context, '/home');
                }
              }
            },
            child: const Text("تأكيد الفك", style: TextStyle(fontFamily: 'Cairo', color: Colors.white, fontWeight: FontWeight.bold))
          ),
        ],
      ),
    );
  }
  // دالة لتحويل الوقت إلى صيغة مقروءة (توضع داخل الكلاس)
  String _getTimeAgo(Timestamp? timestamp) {
    if (timestamp == null) return "غير معروف";
    
    DateTime lastUpdate = timestamp.toDate();
    Duration diff = DateTime.now().difference(lastUpdate);

    if (diff.inMinutes < 1) {
      return "الآن";
    } else if (diff.inMinutes < 60) {
      return "منذ ${diff.inMinutes} دقيقة";
    } else if (diff.inHours < 24) {
      return "منذ ${diff.inHours} ساعة";
    } else {
      return "منذ ${diff.inDays} يوم";
    }
  }
}
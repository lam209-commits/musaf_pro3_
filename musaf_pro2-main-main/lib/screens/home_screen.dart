import 'dart:async'; // 👈 ضروري للـ StreamSubscription
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:musaf_pro/core/theme/app_colors.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart'; // 👈 ضروري لرفع الصور
import 'package:image_picker/image_picker.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import '../providers/location_provider.dart';

class HomeScreen extends StatefulWidget {
  final String? caregiverId;
  const HomeScreen({super.key, this.caregiverId});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}
class _HomeScreenState extends State<HomeScreen> {
  final String? currentUserId = FirebaseAuth.instance.currentUser?.uid;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  
  // 👈 1. تعريف الـ Subscriptions لحل مشكلة تسريب الذاكرة
  StreamSubscription<DocumentSnapshot>? _userSubscription;

  StreamSubscription<QuerySnapshot>? _alertsSubscription;
  
  StreamSubscription<QuerySnapshot>? _zonesSubscription;

  String currentPatientId = ""; 
  String caregiverName = "المرافق";
  String linkedPatientName = "جاري التحميل..."; 
  String caregiverImageUrl = ""; 
  int unreadAlertsCount = 0;
  bool isLoadingData = true;
  
  bool hasSafeZones = true; 
  final Color backgroundLight = const Color(0xFFF8F9FD);

  String get _firstName {
    if (caregiverName.trim().isEmpty) return "المرافق";
    return caregiverName.split(' ').first;
  }
  

 @override
  void initState() {
    super.initState();
    // 🚀 استدعاء الدالة المدمجة التي تجلب البيانات وتراقب الربط
    _initializeCaregiverData();
  }

  void _initializeCaregiverData() {
    final uid = widget.caregiverId ?? currentUserId;
    if (uid == null) return;

    // 1. الاستماع لبيانات المرافق (تحديث الاسم والصورة وحالة الربط تلقائياً)
    _userSubscription = FirebaseFirestore.instance.collection('users').doc(uid).snapshots().listen((userDoc) {
      if (userDoc.exists && mounted) {
        final data = userDoc.data() as Map<String, dynamic>;
        
        // 🛑 التحقق الجذري من حالة الربط (إذا تم فك الارتباط)
        String newPatientId = data['linkedPatientId'] ?? "";
        
        if (newPatientId.isEmpty) {
          // إذا كان الرابط فارغاً، نطرده لشاشة الربط فوراً وبشكل جذري لمنع خطأ الرجوع
          Navigator.pushNamedAndRemoveUntil(context, '/pairing', (route) => false);
          return; // نوقف تنفيذ باقي الدالة
        }

        // ✅ إذا كان مرتبطاً، نقوم بتحديث البيانات
        setState(() {
          caregiverName = data['displayName'] ?? "المرافق";
          caregiverImageUrl = data['profileImageUrl'] ?? "";
          
          // إذا تغير المريض (مثلاً تم ربط مريض جديد)، نجلب بياناته واشتراكاته
          if (newPatientId != currentPatientId) {
            currentPatientId = newPatientId;
            _loadPatientDataAndSubscribers();
          }
          
          isLoadingData = false;
        });
      }
    });
  }
// 2. دالة منفصلة لجلب بيانات المريض والاشتراكات (Alerts & Zones)
Future<void> _loadPatientDataAndSubscribers() async {
  if (currentPatientId.isEmpty) return;

  // جلب اسم المريض
  var patientDoc = await FirebaseFirestore.instance.collection('users').doc(currentPatientId).get();
  if (patientDoc.exists && mounted) {
    setState(() => linkedPatientName = patientDoc.data()?['displayName'] ?? "التابع");
    _saveFamilyTokenToPatient();
  }

  // تحديث الـ Provider
  if (mounted) context.read<LocationProvider>().loadSafeZones(currentPatientId);

  // إعادة ضبط الاشتراكات عند تغيير المريض
  _alertsSubscription?.cancel();
  _zonesSubscription?.cancel();

  _alertsSubscription = FirebaseFirestore.instance
      .collection('patients')
      .doc(currentPatientId)
      .collection('alerts')
      .where('is_read', isEqualTo: false)
      .snapshots()
      .listen((snapshot) {
    if (mounted) setState(() => unreadAlertsCount = snapshot.docs.length);
  });

  _zonesSubscription = FirebaseFirestore.instance
      .collection('patients')
      .doc(currentPatientId)
      .collection('safe_zones')
      .snapshots()
      .listen((snapshot) {
    if (mounted) setState(() => hasSafeZones = snapshot.docs.isNotEmpty);
  });
}
  // 👈 2. تعديل دالة رفع الصورة لاستخدام Firebase Storage
  Future<void> _pickAndUploadProfileImage() async {
    final ImagePicker picker = ImagePicker();
    try {
      final XFile? pickedFile = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 70, // ضغط الصورة لتوفير المساحة
      );

      if (pickedFile != null && currentUserId != null) {
        // إظهار رسالة جاري الرفع
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("جاري رفع الصورة... ⏳", style: TextStyle(fontFamily: 'Cairo'))),
        );

        // رفع الصورة للستوريدج
        final storageRef = FirebaseStorage.instance.ref().child('profile_images').child('$currentUserId.jpg');
        await storageRef.putFile(File(pickedFile.path));
        
        // الحصول على الرابط الدائم
        final downloadUrl = await storageRef.getDownloadURL();

        if (mounted) {
          setState(() {
            caregiverImageUrl = downloadUrl;
          });
        }

        // حفظ الرابط في الفايرستور
        await FirebaseFirestore.instance
            .collection('users')
            .doc(currentUserId)
            .update({'profileImageUrl': downloadUrl});

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("تم تحديث صورة الملف الشخصي بنجاح ✅", style: TextStyle(fontFamily: 'Cairo')),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint("خطأ أثناء اختيار الصورة: $e");
    }
  }
  // ... (نهاية كود _pickAndUploadProfileImage)

  // 👈 الصقي الدالة هنا بالضبط
  Future<void> _saveFamilyTokenToPatient() async {
    if (currentPatientId.isEmpty) return; 
    try {
      FirebaseMessaging messaging = FirebaseMessaging.instance;
      await messaging.requestPermission(alert: true, badge: true, sound: true);
      String? token = await messaging.getToken();
      if (token != null) {
        await FirebaseFirestore.instance.collection('patients').doc(currentPatientId).set({
          'familyFcmToken': token, 
        }, SetOptions(merge: true));
        debugPrint("✅ تم حفظ توكن العائلة بنجاح في حساب المريض!");
      }
    } catch (e) {
      debugPrint("❌ حدث خطأ أثناء حفظ توكن العائلة: $e");
    }
  }


  // 👈 1. تنظيف الذاكرة بشكل سليم
  @override
  void dispose() {
    _alertsSubscription?.cancel();
    _zonesSubscription?.cancel();
    _userSubscription?.cancel(); // 👈 إضافة هامة
    super.dispose();
  }

  

  @override
  Widget build(BuildContext context) {
    if (isLoadingData) {
      return Scaffold(backgroundColor: backgroundLight, body: const Center(child: CircularProgressIndicator(color:  AppColors.primary)));
    }

    // 👈 5. جلب ارتفاع الشاشة لتوزيع المساحات بشكل ديناميكي
    final screenHeight = MediaQuery.of(context).size.height;

    ImageProvider? profileImageProvider; 
    if (caregiverImageUrl.isNotEmpty) {
      if (caregiverImageUrl.startsWith('http')) {
        profileImageProvider = NetworkImage(caregiverImageUrl);
      } else {
        profileImageProvider = FileImage(File(caregiverImageUrl)); // لدعم أي مسارات محلية قديمة أثناء التطوير
      }
    }

    return Consumer<LocationProvider>(
      builder: (context, loc, child) {
        // 👈 4. تصحيح الخطأ المنطقي: الاعتماد على النص الدقيق بدلاً من الرمز المشترك ⚠️
        bool connectionLost = loc.status.contains("فقدان الاتصال");
        bool isConnecting = loc.status.contains("جاري جلب");
        bool isDanger = loc.status.contains("خارج النطاق") || connectionLost;

        Color dynamicColor = AppColors.success; 
    
    if (connectionLost || isDanger) {
      dynamicColor = AppColors.error; 
    } else if (isConnecting) {
      dynamicColor = AppColors.warning; 
    }

        return Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            key: _scaffoldKey,
            backgroundColor: AppColors.background,
            body: currentPatientId.isEmpty 
                ? _buildEmptyState() 
                : _buildMainBody(profileImageProvider, dynamicColor, connectionLost, isConnecting, isDanger, loc.status, screenHeight),
          ),
        );
      },
    );
  }

  Widget _buildMainBody(ImageProvider? profileImage, Color activeColor, bool connectionLost, bool isConnecting, bool isDanger, String statusText, double screenHeight) {    
    return Stack(
      children: [
        SingleChildScrollView(
          // 👈 5. تحديد المسافة العلوية بناءً على نسبة من الشاشة بدلاً من رقم ثابت
          padding: EdgeInsets.only(top: hasSafeZones ? (screenHeight * 0.42) + 10 : 100, left: 20, right: 20, bottom: 20),          
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!hasSafeZones) _buildNoSafeZonesCard(context, activeColor), 
              const SizedBox(height: 10),
              _buildSectionHeaderTitle("الخدمات الأساسية"),
              const SizedBox(height: 15),
              _buildServiceTile("التتبع المباشر", "عرض موقع $linkedPatientName الفعلي", Icons.location_on_rounded, () => Navigator.pushNamed(context, '/map', arguments: currentPatientId), activeColor),
              const SizedBox(height: 12),
              _buildServiceTile("مناطق الأمان", "إدارة المناطق الخاصة بـ $linkedPatientName", Icons.security_rounded, () => Navigator.pushNamed(context, '/add_zone', arguments: currentPatientId), activeColor),
              const SizedBox(height: 12),
              _buildServiceTile("جدول الأدوية", "متابعة المواعيد اليومية", Icons.medication_rounded, () => Navigator.pushNamed(context, '/medications', arguments: currentPatientId), activeColor),
            ],
          ),
        ),
        
        if (hasSafeZones) 
          _buildStatusHeader(isDanger, connectionLost, isConnecting, profileImage, statusText, activeColor, screenHeight),
      ],
    );
  }

Widget _buildStatusHeader(bool isDanger, bool connectionLost, bool isConnecting, ImageProvider? profileImage, String statusText, Color activeColor, double screenHeight) {
  List<Color> gradientColors;
  String title;
  IconData icon;

  if (connectionLost || isDanger) {
    // خطأ أو فقدان اتصال
    gradientColors = [AppColors.error, const Color(0xFF8B0000)]; // أحمر غامق
    title = connectionLost ? "لا يمكن تحديد الموقع: فُقد الاتصال 📡" : "خارج النطاق الآمن الحالي! ⚠️";
    icon = Icons.error_outline_rounded;
  } else if (isConnecting) {
    // جاري الاتصال
    gradientColors = [const Color(0xFFFFB74D), AppColors.warning];
    title = "جاري الاتصال بالنظام...";
    icon = Icons.sync_rounded;
  } else {
    // وضع سليم
    gradientColors = [AppColors.primaryLight, AppColors.success];
    title = "";
    icon = Icons.gpp_good_rounded;
  }

  return AnimatedContainer(
    duration: const Duration(milliseconds: 600),
    curve: Curves.easeInOut,
    height: screenHeight * 0.42,
    width: double.infinity,
    decoration: BoxDecoration(
      gradient: LinearGradient(begin: Alignment.topRight, end: Alignment.bottomLeft, colors: gradientColors),
      borderRadius: const BorderRadius.vertical(bottom: Radius.elliptical(350, 90)),
      boxShadow: [BoxShadow(color: gradientColors.first.withOpacity(0.3), blurRadius: 15, offset: const Offset(0, 5))],
    ),
    child: ClipRRect(
      borderRadius: const BorderRadius.vertical(bottom: Radius.elliptical(350, 90)),
      child: Stack(
        children: [
          // 1. الدوائر الزخرفية في الخلفية (التي كنتِ تريدين استعادتها)
          Center(child: Container(height: 220, width: 220, decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withOpacity(0.08)))),
          Center(child: Container(height: 140, width: 140, decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withOpacity(0.08)))),
          Center(child: Container(height: 80, width: 80, decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withOpacity(0.08)))),
                    Center(child: Container(height: 280, width: 280, decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withOpacity(0.08)))),

          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Column(
                children: [
                  // 2. الجزء العلوي (الصورة + الاسم + التنبيهات)
                  Row(
                    children: [
                      GestureDetector(
                        onTap: _pickAndUploadProfileImage,
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.white.withOpacity(0.5), width: 1.5)),
                          child: CircleAvatar(
                            radius: 20,
                            backgroundColor: Colors.white24,
                            backgroundImage: profileImage,
                            child: profileImage == null ? const Icon(Icons.person, color: Colors.white) : null,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text("حياك الله", style: TextStyle(fontFamily: 'Cairo', fontSize: 13, color: Colors.white70)),
                          Text(_firstName, style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 22, color: Colors.white)),
                        ],
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.notifications_none_rounded, color: Colors.white, size: 28),
                        onPressed: () {
                           if (currentPatientId.isNotEmpty) {
                             Navigator.pushNamed(context, '/notifications', arguments: currentPatientId);
                           }
                        },
                      ),
                    ],
                  ),
                  
                  // 3. دفع حالة الاتصال للأسفل
                  const Spacer(),
                  
                  // 4. منطقة حالة الاتصال
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 500),
                      child: Row(
                        key: ValueKey(title + statusText),
                        children: [
                          Icon(icon, color: Colors.white, size: 28),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (title.isNotEmpty) Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontFamily: 'Cairo', fontSize: 14)),
                                Text(connectionLost ? "يرجى التحقق من اتصال جهاز $linkedPatientName بالإنترنت." : statusText,
                                    style: const TextStyle(fontFamily: 'Cairo', fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white, height: 1.4)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 15),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

  Widget _buildNoSafeZonesCard(BuildContext context, Color activeColor) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white, 
        borderRadius: BorderRadius.circular(20), 
        boxShadow: [BoxShadow(color: activeColor.withOpacity(0.08), blurRadius: 10, offset: const Offset(0, 4))],
        border: Border.all(color: activeColor.withOpacity(0.2), width: 1.5)
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.location_off_rounded, color: activeColor, size: 24),
              const SizedBox(width: 8),
              const Text("لم يتم تفعيل التتبع", style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontFamily: 'Cairo', fontSize: 16)),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            "أضف منطقة أمان للتابع ($linkedPatientName) للبدء في تتبع الموقع وتلقي التنبيهات الجغرافية.", 
            style: TextStyle(fontFamily: 'Cairo', fontSize: 13, color: Colors.grey[700], height: 1.4)
          ),
          const SizedBox(height: 15),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => Navigator.pushNamed(context, '/add_zone', arguments: currentPatientId),
              icon: const Icon(Icons.add_location_alt_rounded, color: Colors.white, size: 20),
              label: const Text("إضافة منطقة أمان الآن", style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, color: Colors.white)),
              style: ElevatedButton.styleFrom(
                backgroundColor: activeColor,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                elevation: 0,
              ),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildServiceTile(String title, String sub, IconData icon, VoidCallback onTap, Color activeColor) {
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15), side: BorderSide(color: Colors.grey.withOpacity(0.1))),
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        title: Text(title, style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 15)),
        subtitle: Text(sub, style: TextStyle(fontFamily: 'Cairo', fontSize: 12, color: Colors.grey[600])),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: activeColor.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, color: activeColor), 
        ),
        trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16, color: Colors.black38),
      ),
    );
  }

 Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.link_off_rounded, size: 80, color: Colors.grey[400]),
            const SizedBox(height: 16),
            const Text(
              "لم يتم ربط أي تابع بحسابك!", 
              style: TextStyle(fontFamily: 'Cairo', fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)
            ),
            const SizedBox(height: 10),
            const Text(
              "لا يمكنك استخدام لوحة التحكم وتتبع الحالة قبل إدخال كود الربط الخاص بالتابع.", 
              textAlign: TextAlign.center,
              style: TextStyle(fontFamily: 'Cairo', fontSize: 14, color: Colors.grey, height: 1.5)
            ),
            const SizedBox(height: 30),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: () => Navigator.pushNamed(context, '/pairing'), 
                icon: const Icon(Icons.qr_code_scanner_rounded, color: Colors.white),
                label: const Text("إدخال كود الربط الآن", style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2E7D32),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeaderTitle(String title) => Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17, fontFamily: 'Cairo'));
}
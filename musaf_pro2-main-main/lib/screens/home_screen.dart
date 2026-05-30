import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';

import '../providers/location_provider.dart';
import 'settings_screen.dart'; 

class HomeScreen extends StatefulWidget {
  final String? caregiverId;
  const HomeScreen({super.key, this.caregiverId});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final String? currentUserId = FirebaseAuth.instance.currentUser?.uid;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  
  String currentPatientId = ""; 
  String caregiverName = "المرافق";
  String linkedPatientName = "جاري التحميل..."; 
  String caregiverImageUrl = ""; 
  int unreadAlertsCount = 0;
  bool isLoadingData = true;
  
  bool hasSafeZones = true; 
  final Color backgroundLight = const Color(0xFFF8F9FD);

  // تم حذف اللون البنفسجي الثابت من هنا ليتم حسابه ديناميكياً

  String get _firstName {
    if (caregiverName.trim().isEmpty) return "المرافق";
    return caregiverName.split(' ').first;
  }

  @override
  void initState() {
    super.initState();
    _initializeCaregiverData();
  }

  Future<void> _initializeCaregiverData() async {
    final uid = widget.caregiverId ?? FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      try {
        var userDoc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
        if (userDoc.exists && mounted) {
          setState(() {
            caregiverName = userDoc.data()?['displayName'] ?? "المرافق";
            caregiverImageUrl = userDoc.data()?['profileImageUrl'] ?? ""; 
            currentPatientId = userDoc.data()?['linkedPatientId'] ?? "";
          });
          
          if (currentPatientId.isNotEmpty) {
            var patientDoc = await FirebaseFirestore.instance.collection('users').doc(currentPatientId).get();
            if (patientDoc.exists && mounted) {
              setState(() {
                linkedPatientName = patientDoc.data()?['displayName'] ?? "التابع";
              });
            } else {
              setState(() => linkedPatientName = "لم يتم العثور على بيانات التابع");
            }

            final pro = context.read<LocationProvider>();
            await pro.loadSafeZones(currentPatientId);
            
            FirebaseFirestore.instance.collection('patients').doc(currentPatientId).collection('alerts').where('is_read', isEqualTo: false).snapshots().listen((snapshot) {
              if (mounted) setState(() => unreadAlertsCount = snapshot.docs.length);
            });

            FirebaseFirestore.instance.collection('patients').doc(currentPatientId).collection('safe_zones').snapshots().listen((snapshot) {
              if (mounted) {
                setState(() {
                  hasSafeZones = snapshot.docs.isNotEmpty;
                });
              }
            });

            setState(() => isLoadingData = false);
          } else {
            setState(() => linkedPatientName = "لم تقم بربط تابع حتى الآن");
            if (mounted) setState(() => isLoadingData = false);
          }
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            linkedPatientName = "خطأ في جلب البيانات";
            isLoadingData = false;
          });
        }
      }
    }
  }
  Future<void> _pickAndUploadProfileImage() async {
    final ImagePicker picker = ImagePicker();
    try {
      final XFile? pickedFile = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 70,
      );

      if (pickedFile != null && currentUserId != null) {
        setState(() {
          caregiverImageUrl = pickedFile.path;
        });

        await FirebaseFirestore.instance
            .collection('users')
            .doc(currentUserId)
            .update({'profileImageUrl': pickedFile.path});

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

  @override
  Widget build(BuildContext context) {
    if (isLoadingData) {
      return Scaffold(backgroundColor: backgroundLight, body: const Center(child: CircularProgressIndicator(color: Color(0xFF2E7D32))));
    }

   ImageProvider? profileImageProvider; // أضفنا علامة الاستفهام ? لجعله يقبل قيمة فارغة
    if (caregiverImageUrl.isNotEmpty) {
      if (caregiverImageUrl.startsWith('http')) {
        profileImageProvider = NetworkImage(caregiverImageUrl);
      } else {
        profileImageProvider = FileImage(File(caregiverImageUrl));
      }
    } else {
      profileImageProvider = null; // التعديل هنا: جعلناها null بدلاً من AssetImage
    }
    // هنا يتم تحديث حالة الألوان لجميع الشاشة بناءً على حالة المريض
    return Consumer<LocationProvider>(
      builder: (context, loc, child) {
        bool connectionLost = loc.status.contains("فقدان الاتصال") || loc.status.contains("⚠️");
        bool isConnecting = loc.status.contains("جاري جلب");
        bool isDanger = loc.status.contains("خارج النطاق") || connectionLost;

        // اللون الديناميكي الذي سيطبق على الخدمات والدرج
        Color dynamicColor = const Color(0xFF2E7D32); // أخضر كافتراضي
        if (connectionLost || isDanger) {
          dynamicColor = const Color(0xFFFF5252); // أحمر
        } else if (isConnecting) {
          dynamicColor = const Color(0xFFF57C00); // برتقالي
        }

        return Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            key: _scaffoldKey,
            backgroundColor: backgroundLight,
            // تمرير اللون الديناميكي للدرج
            body: currentPatientId.isEmpty 
                ? _buildEmptyState() 
                : _buildMainBody(profileImageProvider, dynamicColor, connectionLost, isConnecting, isDanger, loc.status),
          ),
        );
      },
    );
  }

Widget _buildMainBody(ImageProvider? profileImage, Color activeColor, bool connectionLost, bool isConnecting, bool isDanger, String statusText) {    return Stack(
      children: [
        // 1. المحتوى القابل للتمرير أصبح في الأسفل ليسمح للأزرار العلوية بالعمل
        SingleChildScrollView(
padding: EdgeInsets.only(top: hasSafeZones ? 370 : 100, left: 20, right: 20, bottom: 20),          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!hasSafeZones) _buildNoSafeZonesCard(context, activeColor), 
              const SizedBox(height: 10),
              _buildSectionHeaderTitle("الخدمات الأساسية"),
              const SizedBox(height: 15),
              _buildServiceTile("التتبع المباشر", "عرض موقع $linkedPatientName الفعلي", Icons.location_on_rounded, () => Navigator.pushNamed(context, '/map', arguments: currentPatientId), activeColor),
              const SizedBox(height: 12),
              _buildServiceTile("مناطق الأمان", "إدارة المناطق الخاضه ب$linkedPatientName ", Icons.security_rounded, () => Navigator.pushNamed(context, '/add_zone', arguments: currentPatientId), activeColor),
              const SizedBox(height: 12),
              _buildServiceTile("جدول الأدوية", "متابعة المواعيد اليومية", Icons.medication_rounded, () => Navigator.pushNamed(context, '/medications', arguments: currentPatientId), activeColor),
            ],
          ),
        ),
        
        // 2. الترويسة الملونة أصبحت في الأعلى لتستقبل ضغطات المستخدم دون مشكلة
        if (hasSafeZones) 
          _buildStatusHeader(isDanger, connectionLost, isConnecting, profileImage, statusText, activeColor),
      ],
    );
  }

Widget _buildStatusHeader(bool isDanger, bool connectionLost, bool isConnecting, ImageProvider? profileImage, String statusText, Color activeColor) {    List<Color> gradientColors;
    String title;
    IconData icon;

    if (connectionLost || isDanger) {
      gradientColors = [const Color(0xFFFF5252), const Color(0xFFC62828)]; 
      title = connectionLost ? "لا يمكن تحديد الموقع: فُقد الاتصال 📡" : "خارج النطاق الآمن الحالي! ⚠️";
      icon = connectionLost ? Icons.error_outline_rounded : Icons.gpp_bad_rounded;
    } else if (isConnecting) {
      gradientColors = [const Color(0xFFFFB74D), const Color(0xFFF57C00)]; 
      title = "جاري الاتصال بالنظام...";
      icon = Icons.sync_rounded;
    } else {
      gradientColors = [const Color(0xFF81C784), const Color(0xFF2E7D32)]; 
      title = "";
      icon = Icons.gpp_good_rounded;
    }

    // 1. إضافة AnimatedContainer لتنعيم انتقال ألوان الخلفية
    return AnimatedContainer(
      duration: const Duration(milliseconds: 600), // مدة حركة تغير اللون
      curve: Curves.easeInOut,
      height: 370, // تم زيادة الارتفاع قليلاً لتجنب خطأ الـ Overflow بسبب مسافة الـ 90
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
            Center(child: Container(height: 220, width: 220, decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withOpacity(0.08)))),
            Center(child: Container(height: 140, width: 140, decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withOpacity(0.08)))),
            Center(child: Container(height: 80, width: 80, decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withOpacity(0.08)))),
            
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // شريط الأيقونات العلوي
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        GestureDetector(
                          child: Container(
                            padding: const EdgeInsets.all(2),
                            decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.white.withOpacity(0.5), width: 1.5)),
                            child: CircleAvatar(
                              radius: 18,
                              backgroundColor: Colors.white24,
                              backgroundImage: profileImage,
                              // التعديل هنا: إضافة الأيقونة في حال لم تكن هناك صورة
                              child: profileImage == null ? const Icon(Icons.person, color: Colors.white) : null,
                            ),
                          ),
                        ),
                        Stack(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.notifications_none_rounded, color: Colors.white, size: 28),
                              onPressed: () {
                                if (currentPatientId.isNotEmpty) {
                                  Navigator.pushNamed(context, '/notifications', arguments: currentPatientId);
                                } else {
                                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("يجب ربط مريض أولاً لعرض التنبيهات", style: TextStyle(fontFamily: 'Cairo'))));
                                }
                              },
                            ),
                            if (unreadAlertsCount > 0)
                              Positioned(
                                top: 8, right: 8,
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: const BoxDecoration(color: Colors.amber, shape: BoxShape.circle),
                                  constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                                  child: Text('$unreadAlertsCount', style: const TextStyle(color: Colors.black87, fontSize: 10, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                    const Spacer(),
                    
                    // نصوص الترحيب
                    const Text("مرحباً بك،", style: TextStyle(fontFamily: 'Cairo', fontSize: 14, color: Colors.white70)),
                    Text(_firstName, style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 26, color: Colors.white, height: 1.2)),
                    
                    const SizedBox(height: 100), 
                    
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(15),
                      ),
                      // 2. إضافة AnimatedSwitcher لحركة تغير محتوى الكرت
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 500),
                        transitionBuilder: (Widget child, Animation<double> animation) {
                          return FadeTransition(
                            opacity: animation,
                            child: SlideTransition(
                              position: Tween<Offset>(begin: const Offset(0.0, 0.2), end: Offset.zero).animate(animation),
                              child: child,
                            ),
                          );
                        },
                        // المفتاح هنا يخبر فلاتر متى يجب تفعيل الأنيميشن
                        child: Row(
                          key: ValueKey<String>(title + statusText),
                          children: [
                            Icon(icon, color: Colors.white, size: 28),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  // 3. التحقق من وجود العنوان لإخفائه مع مسافته في الوضع الآمن
                                  if (title.isNotEmpty) ...[
                                    Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontFamily: 'Cairo', fontSize: 16)),
                                    const SizedBox(height: 4),
                                  ],
                                  Text(connectionLost ? "يرجى التحقق من اتصال جهاز $linkedPatientName بالإنترنت." : statusText, 
                                      style: const TextStyle(
                                        fontFamily: 'Cairo', 
                                        fontSize: 13, 
                                        fontWeight: FontWeight.bold, 
                                        color: Colors.white, 
                                        height: 1.4)),
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


  Widget _buildCleanInfoTile(String title, String subtitle, IconData icon, Color activeColor) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 2),
      leading: Icon(icon, color: activeColor.withOpacity(0.7), size: 22),
      title: Text(title, style: TextStyle(fontFamily: 'Cairo', fontSize: 11, color: Colors.grey[500])),
      subtitle: Text(
        subtitle, 
        style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black87),
        overflow: TextOverflow.ellipsis,
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
          child: Icon(icon, color: activeColor), // تغيير لون أيقونات الخدمات ليتوافق مع الحالة
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
                // تأكدي من أن '/pairing' هو المسار الصحيح لشاشة إدخال الكود في ملف routes
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
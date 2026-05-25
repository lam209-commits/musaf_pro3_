import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:musaf_pro/screens/notifications_screen.dart';
import 'package:musaf_pro/widgets/custom_button.dart';
import 'package:musaf_pro/screens/settings_screen.dart';
import 'package:musaf_pro/screens/wound_screen.dart';

// 🚀 استيرادات الصفحات الجديدة
import 'package:musaf_pro/screens/patient_sos_page.dart';
import 'package:musaf_pro/screens/educational_library_page.dart';
// 🚀 استيراد صفحة الأدوية اليومية الجديدة
import 'package:musaf_pro/screens/daily_medications_list_screen.dart';

class PatientHomeScreen extends StatefulWidget {
  const PatientHomeScreen({super.key});

  @override
  State<PatientHomeScreen> createState() => _PatientHomeScreenState();
}

class _PatientHomeScreenState extends State<PatientHomeScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _sosController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _shadowAnimation;
  int _currentIndex = 0;
  final Color musafRed = const Color(0xFFB7131A);
  final Color musafTeal = const Color(0xFF006D77);

  String _userName = '...';
  late Stream<int> _medsStream;

  @override
  void initState() {
    super.initState();
    _fetchUserName();
    _medsStream = _getIncomingMedsCount();

    _sosController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);

    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 1.05,
    ).animate(CurvedAnimation(parent: _sosController, curve: Curves.easeInOut));

    _shadowAnimation = Tween<double>(
      begin: 2,
      end: 12,
    ).animate(CurvedAnimation(parent: _sosController, curve: Curves.easeInOut));
  }

  Stream<int> _getIncomingMedsCount() {
    String? userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return Stream.value(0);

    return FirebaseFirestore.instance
        .collection('medications')
        .where('userId', isEqualTo: userId)
        .where('isTakenToday', isEqualTo: false)
        .snapshots()
        .map((snapshot) {
          int count = 0;
          DateTime now = DateTime.now();

          for (var doc in snapshot.docs) {
            List times = doc['times'] ?? [];
            for (String timeStr in times) {
              try {
                int medHour = int.parse(timeStr.trim().split(':')[0]);
                int medMinute = int.parse(timeStr.trim().split(':')[1]);

                DateTime medDateTime = DateTime(
                  now.year,
                  now.month,
                  now.day,
                  medHour,
                  medMinute,
                );
                int diff = medDateTime.difference(now).inMinutes;

                if (diff >= -30 && diff <= 5) {
                  count++;
                }
              } catch (e) {
                continue;
              }
            }
          }
          return count;
        });
  }

  // 🛡️ التعديل الجوهري: حماية الـ setState باستخدام if (mounted) لمنع الكراش
  Future<void> _fetchUserName() async {
    try {
      String? userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId != null) {
        DocumentSnapshot userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .get();
        if (userDoc.exists && userDoc.data() != null) {
          String fullName = userDoc.get('displayName') ?? '';
          if (fullName.isNotEmpty) {
            if (mounted) {
              setState(() {
                _userName = fullName.split(' ')[0];
              });
            }
          } else {
            if (mounted) setState(() => _userName = 'بك');
          }
        }
      }
    } catch (e) {
      debugPrint("Error fetching user name: $e");
      if (mounted) setState(() => _userName = 'بك');
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final screenWidth = size.width;
    final screenHeight = size.height;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
        leading: Center(
          child: StreamBuilder<int>(
            stream: _medsStream,
            builder: (context, snapshot) {
              int count = snapshot.data ?? 0;
              return Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.notifications_none_rounded),
                      color: Colors.black87,
                      iconSize: 22,
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const NotificationsScreen(),
                          ),
                        );
                      },
                    ),
                  ),
                  if (count > 0)
                    Positioned(
                      right: -2,
                      top: -2,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 16,
                          minHeight: 16,
                        ),
                        child: Text(
                          '$count',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
        title: const Text(
          'مُسعف',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color(0xFFB7131A),
          ),
        ),
        centerTitle: true,
      ),

      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(
            horizontal: screenWidth * 0.05,
            vertical: screenHeight * 0.01,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                'أهلاً، $_userName',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              SizedBox(height: screenHeight * 0.015),

              // --- 1. كارد القياسات الحيوية ---
              InkWell(
                onTap: () => Navigator.pushNamed(context, '/health_vitals'),
                borderRadius: BorderRadius.circular(15),
                child: Container(
                  padding: EdgeInsets.all(screenWidth * 0.035),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.arrow_back_ios, size: 14, color: musafRed),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'تحديث القياسات الحيوية',
                          textAlign: TextAlign.right,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: musafRed.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.monitor_heart_outlined,
                          color: musafRed,
                          size: 20,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              SizedBox(height: screenHeight * 0.015),

              // --- 2. كارد حالة الطوارئ (SOS) ---
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(screenWidth * 0.04),
                decoration: BoxDecoration(
                  color: musafRed.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: musafRed.withOpacity(0.2)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    // 🔺 العنوان
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                          'حالة الطوارئ',
                          style: TextStyle(
                            color: musafRed,
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Icon(Icons.warning_rounded, color: musafRed, size: 20),
                      ],
                    ),

                    const SizedBox(height: 6),

                    // 📝 الوصف
                    const Text(
                      'اضغط على الزر أدناه لطلب مساعدة فورية وتنبيه المرافقين.',
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        color: Colors.black87,
                        fontSize: 12,
                        height: 1.4,
                      ),
                    ),

                    const SizedBox(height: 12),

                    // 🚨 زر SOS مع أنيميشن (Pulse + Glow)
                    AnimatedBuilder(
                      animation: _sosController,
                      builder: (context, child) {
                        return Transform.scale(
                          scale: 1.0 + (_scaleAnimation.value - 1.0),
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              // 🔴 Glow متحرك
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.red.withOpacity(0.35),
                                  blurRadius: _shadowAnimation.value,
                                  spreadRadius: 2,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                            ),
                            child: child,
                          ),
                        );
                      },
                      child: CustomButton(
                        text: 'طلب تدخل طارئ (SOS)',
                        isPrimary: true,
                        backgroundColor: musafRed,
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const PatientSOSPage(),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),

              SizedBox(height: screenHeight * 0.015),
              
              // --- 3. كارد المكتبة التعليمية ---
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(screenWidth * 0.04),
                decoration: BoxDecoration(
                  color: const Color(0xFFEDF4F4),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: musafTeal.withOpacity(0.15)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                          'المكتبة التعليمية',
                          style: TextStyle(
                            color: musafTeal,
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: musafTeal.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.menu_book_rounded,
                            color: musafTeal,
                            size: 18,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'تصفح المقالات والإرشادات الطبية الموثوقة لحياة صحية أفضل لك ولمن تحب.',
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        color: Colors.black87,
                        fontSize: 12,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 12),
                    CustomButton(
                      text: 'تصفح المكتبة',
                      isPrimary: true,
                      backgroundColor: musafTeal,
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const EducationalLibraryPage(),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
              SizedBox(height: screenHeight * 0.015),
            ],
          ),
        ),
      ),

      floatingActionButton: SizedBox(
        width: 55,
        height: 55,
        child: FloatingActionButton(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute( 
                builder: (context) =>  HomePage(),
              ),
            );
          },
          backgroundColor: musafRed,
          shape: const CircleBorder(),
          child: const Icon(Icons.camera_alt, color: Colors.white, size: 24),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,

      bottomNavigationBar: BottomAppBar(
        shape: const CircularNotchedRectangle(),
        notchMargin: 6.0,
        color: Colors.white,
        elevation: 10,
        child: SizedBox(
          height: 60,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // ↙️ الجانب الأيسر
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildNavItem(
                      Icons.settings,
                      'إعدادات',
                      3,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const SettingsScreen(),
                          ),
                        );
                      },
                    ),
                    _buildNavItem(Icons.favorite_border_rounded, 'أطبائي', 2),
                  ],
                ),
              ),

              const SizedBox(width: 40),

              // ↘️ الجانب الأيمن
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildNavItem(
                      Icons.medical_services_outlined,
                      'الأدوية',
                      1,
                      onTap: () {
                        Navigator.pushNamed(context, '/daily_medications');
                      },
                    ),
                    _buildNavItem(Icons.home, 'الرئيسية', 0, isActive: true),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(
    IconData icon,
    String label,
    int index, {
    bool isActive = false,
    VoidCallback? onTap,
  }) {
    Color itemColor = isActive ? musafRed : Colors.grey.shade600;
    return InkWell(
      onTap: onTap ?? () => setState(() => _currentIndex = index),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2.0, vertical: 2.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: itemColor, size: 22),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: itemColor,
                fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _sosController.dispose(); 
    super.dispose();
  }
}
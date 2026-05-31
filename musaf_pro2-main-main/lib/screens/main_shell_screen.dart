import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

// 🚀 استدعاء شاشاتك الأربعة اللي نظفناها سوا
import 'package:musaf_pro/screens/patient_home_screen.dart';
import 'package:musaf_pro/screens/medications_screen.dart';
import 'package:musaf_pro/screens/health_vitals_screen.dart';

class MainShellScreen extends StatefulWidget {
  const MainShellScreen({super.key});

  @override
  State<MainShellScreen> createState() => _MainShellScreenState();
}

class _MainShellScreenState extends State<MainShellScreen> {
  final Color musafRed = const Color(0xFFB7131A);
  int _selectedIndex = 0;

  // 🎯 مصفوفة الشاشات المربوطة بالبار السفلي بالترتيب
  final List<Widget> _pages = [
    const PatientHomeScreen(), // الرئيسية (Index 0)
    const MedicationsScreen(), // الأدوية (Index 1)
    const HealthVitalsScreen(), // القياسات الحيوية (Index 2)
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,

      // 1️⃣ الـ AppBar الموحد والثابت في كل شاشات التطبيق
      appBar: AppBar(
        backgroundColor: musafRed,
        foregroundColor: Colors.white,
        title: const Text(
          "مُسعف",
          style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.2),
        ),
        centerTitle: true,
        elevation: 2,
        leading: IconButton(
          icon: const Icon(Icons.settings), // ⚙️ زر الإعدادات الموحد يسار
          onPressed: () {
            debugPrint("فتح الإعدادات العامة");
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout), // 🚪 زر تسجيل الخروج الموحد يمين
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              if (context.mounted) {
                Navigator.pushReplacementNamed(context, '/role_selection');
              }
            },
          ),
        ],
      ),

      // 2️⃣ عرض محتوى الشاشات الفرعية بدون ما يختفي البار أو الـ AppBar
      body: IndexedStack(index: _selectedIndex, children: _pages),

      // 3️⃣ زر الكاميرا الدائري البارز والمثبت في منتصف الناف بار تماماً
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          debugPrint("تشغيل كاميرا مسعف الذكية");
        },
        backgroundColor: musafRed,
        elevation: 6,
        shape: const CircleBorder(), // يضمن دائرية الزر الكاملة لتطابق التصميم
        child: const Icon(Icons.camera_alt, color: Colors.white, size: 28),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,

      // 4️⃣ البار السفلي الموحد والمقوس بانسيابية (BottomAppBar)
      bottomNavigationBar: BottomAppBar(
        shape: const CircularNotchedRectangle(), // يعمل انحناء حول زر الكاميرا
        notchMargin: 8.0,
        color: Colors.white,
        elevation: 15,
        child: SizedBox(
          height: 60,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // --- الجهة اليسرى: الرئيسية والأدوية ---
              Row(
                children: [
                  _buildBottomItem(Icons.home, "الرئيسية", 0),
                  _buildBottomItem(Icons.medical_services, "الأدوية", 1),
                ],
              ),

              // مسافة فارغة مخصصة لزر الكاميرا في المنتصف لمنع التداخل
              const SizedBox(width: 40),

              // --- الجهة اليمنى: القياسات والمرضى ---
              Row(
                children: [
                  _buildBottomItem(Icons.monitor_heart, "القياسات", 2),
                  _buildBottomItem(Icons.people, "المرضى", 3),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // دالة مساعدة لبناء أزرار الناف بار بأناقة وحساب التحديد
  Widget _buildBottomItem(IconData icon, String label, int index) {
    final bool isSelected = _selectedIndex == index;
    return MaterialButton(
      minWidth: 65,
      onPressed: () => setState(() => _selectedIndex = index),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            color: isSelected ? musafRed : Colors.grey.shade500,
            size: 24,
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              color: isSelected ? musafRed : Colors.grey.shade600,
            ),
          ),
        ],
      ),
    ); // 🚀 تم إصلاح القفلة هنا بنجاح ✅
  }
}

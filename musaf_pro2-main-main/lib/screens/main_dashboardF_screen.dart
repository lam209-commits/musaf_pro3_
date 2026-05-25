import 'package:flutter/material.dart';
import 'package:musaf_pro/screens/home_screen.dart'; // تأكد من استيراد المسار الصحيح
import 'package:musaf_pro/screens/family_alerts_screen.dart';
import 'package:musaf_pro/screens/settingsF_screen.dart';
import 'package:musaf_pro/screens/settings_screen.dart'; // تأكد من استيراد شاشة الإعدادات
import 'package:musaf_pro/widgets/custom_bottom_nav.dart';

class MainDashboardScreen extends StatefulWidget {
  const MainDashboardScreen({super.key});

  @override
  State<MainDashboardScreen> createState() => _MainDashboardScreenState();
}

class _MainDashboardScreenState extends State<MainDashboardScreen> {
  int _currentIndex = 0;

  final List<Widget> _pages = [
    const HomeScreen(), // لا تحتاج لتمرير ID هنا إذا كنت تجلبه داخل الـ Screen نفسها
    const FamilyAlertsScreen(patientId: "YOUR_PATIENT_ID"), // استبدل بآلية جلب الـ ID
    const CaregiverSettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    // يمكنك هنا جلب اللون ديناميكياً من Provider
    const Color activeColor = Color(0xFF2E7D32); 

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _pages,
      ),
      bottomNavigationBar: CustomBottomNav(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        activeColor: activeColor,
      ),
    );
  }
}
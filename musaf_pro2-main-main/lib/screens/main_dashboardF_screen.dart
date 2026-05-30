import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart'; // تم إضافة مكتبة البروفايدر

import 'package:musaf_pro/screens/home_screen.dart'; 
import 'package:musaf_pro/screens/family_alerts_screen.dart';
import 'package:musaf_pro/screens/settingsF_screen.dart'; 
import 'package:musaf_pro/widgets/custom_bottom_nav.dart';
import '../providers/location_provider.dart'; // تأكدي من مسار ملف الـ LocationProvider

class MainDashboardScreen extends StatefulWidget {
  const MainDashboardScreen({super.key});

  @override
  State<MainDashboardScreen> createState() => _MainDashboardScreenState();
}

class _MainDashboardScreenState extends State<MainDashboardScreen> {
  int _currentIndex = 0;
  String _currentPatientId = "";
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchLinkedPatientId();
  }

  Future<void> _fetchLinkedPatientId() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        var doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
        if (doc.exists && mounted) {
          setState(() {
            _currentPatientId = doc.data()?['linkedPatientId'] ?? "";
            _isLoading = false;
          });
        }
      } catch (e) {
        debugPrint("خطأ في جلب بيانات المريض: $e");
        if (mounted) setState(() => _isLoading = false);
      }
    } else {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // إظهار شاشة تحميل ريثما يتم جلب الـ ID
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFFF8F9FD),
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFF2E7D32)),
        ),
      );
    }

    final List<Widget> pages = [
      const HomeScreen(), 
      FamilyAlertsScreen(patientId: _currentPatientId), 
      const CaregiverSettingsScreen(), 
    ];

    // 👈 التعديل السحري هنا: قراءة حالة المريض وتحديد اللون ديناميكياً
    return Consumer<LocationProvider>(
      builder: (context, locProvider, child) {
        // التحقق مما إذا كانت الحالة تحتوي على كلمات تدل على الخطر
        bool isDanger = locProvider.status.contains("خارج") || 
                        locProvider.status.contains("فقدان") || 
                        locProvider.status.contains("⚠️");

        // تغيير اللون بناءً على الحالة
        Color dynamicActiveColor = isDanger ? Colors.red : const Color(0xFF2E7D32);

        return Scaffold(
          body: IndexedStack(
            index: _currentIndex,
            children: pages,
          ),
          bottomNavigationBar: CustomBottomNav(
            currentIndex: _currentIndex,
            onTap: (index) => setState(() => _currentIndex = index),
            activeColor: dynamicActiveColor, // تمرير اللون الديناميكي للشريط
          ),
        );
      },
    );
  }
}
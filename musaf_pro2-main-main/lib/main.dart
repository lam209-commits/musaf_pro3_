import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:permission_handler/permission_handler.dart'; 
import 'package:shared_preferences/shared_preferences.dart'; // 👈 ضروري لفحص شاشة الترحيب

import 'firebase_options.dart';
import 'package:musaf_pro/services/notification_service.dart';
import 'package:musaf_pro/providers/location_provider.dart';
import 'package:musaf_pro/data/repositories/firebase_zone_repository.dart';

// 🚀 استدعاء AuthWrapper الذي صنعناه مسبقاً (تأكدي من المسار الصحيح)
import 'package:musaf_pro/screens/auth/auth_wrapper.dart'; 

import 'package:musaf_pro/screens/home_screen.dart' as caregiver_home;
import 'package:musaf_pro/screens/main_dashboardF_screen.dart';
import 'package:musaf_pro/screens/map_screen.dart';
import 'package:musaf_pro/screens/add_zone_screen.dart';
import 'package:musaf_pro/screens/family_alerts_screen.dart';
import 'package:musaf_pro/screens/splash_screen.dart';
import 'package:musaf_pro/screens/onboarding_screen.dart';
import 'package:musaf_pro/screens/patient_or_the_companion/role_selection_screen.dart';
import 'package:musaf_pro/screens/auth/login_screen.dart';
import 'package:musaf_pro/screens/auth/register_screen.dart';
import 'package:musaf_pro/screens/auth/pairing_code_screen.dart';
import 'package:musaf_pro/screens/auth/health_data_screen.dart';
import 'package:musaf_pro/screens/patient_home_screen.dart';
import 'package:musaf_pro/screens/health_vitals_screen.dart';
import 'package:musaf_pro/screens/medications_screen.dart';
import 'package:musaf_pro/screens/daily_medications_list_screen.dart';
import 'screens/patient_verification_screen.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  await NotificationService.init();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => LocationProvider(FirebaseZoneRepository())),    
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'مُسعف',
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: 'Almarai', // يمكنكِ تغييره إلى Cairo إذا أردتِ توحيد الخطوط
        primarySwatch: Colors.red,
        scaffoldBackgroundColor: Colors.white,
      ),
      home: const AppInitGate(), // 👈 البوابة الذكية التي تفحص الـ Onboarding
      routes: {
        '/splash': (context) => const SplashScreen(),
        '/onboarding': (context) => const OnboardingScreen(),
        '/role_selection': (context) => const RoleSelectionScreen(),
        '/login': (context) => const LoginScreen(),
        '/register': (context) => const RegisterScreen(),
        '/pairing': (context) => const PairingCodeScreen(),
        '/health_data': (context) => const HealthDataScreen(),
        '/health_vitals': (context) => const HealthVitalsScreen(),
        '/medications': (context) => const MedicationsScreen(),
        '/daily_medications': (context) => const DailyMedicationsListScreen(),
        '/patient_home': (context) => const PatientHomeScreen(),
        
        // 🚀 توجيه /home يمر عبر شاشة الأذونات أولاً لضمان الأمان
        '/home': (context) => const PermissionHandlerWrapper(), 
        
        '/patient_verification': (context) => const PatientVerificationScreen(),
      },
      onGenerateRoute: (settings) {
        final String patientId = settings.arguments is String ? settings.arguments as String : "user_123";
        
        switch (settings.name) {
          case '/caregiver_home':
            final String? caregiverId = settings.arguments as String?;
            return MaterialPageRoute(
              builder: (context) => caregiver_home.HomeScreen(caregiverId: caregiverId),
            );
          case '/map':
            return MaterialPageRoute(builder: (context) => MapScreen(patientId: patientId));
          case '/add_zone':
            return MaterialPageRoute(builder: (context) => AddZoneScreen(patientId: patientId));
          case '/notifications':
            return MaterialPageRoute(builder: (context) => FamilyAlertsScreen(patientId: patientId));
          default:
            return null;
        }
      },
    );
  }
}

// 🚀 البوابة الذكية الجديدة: تفحص هل شاهد المستخدم شاشة الترحيب أم لا
class AppInitGate extends StatelessWidget {
  const AppInitGate({super.key});

  Future<bool> _checkFirstSeen() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('hasSeenOnboarding') ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _checkFirstSeen(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SplashScreen(); // عرض السبلاش أثناء الفحص
        }
        
        final bool hasSeenOnboarding = snapshot.data ?? false;
        
        // التوجيه: إما حارس البوابة (AuthWrapper) أو شاشة الترحيب
        return hasSeenOnboarding ? const AuthWrapper() : const OnboardingScreen();
      },
    );
  }
}

// 🚀 تم تحسين شاشة الأذونات لتكون "غلافاً" حقيقياً لا يخرب سجل التنقل
class PermissionHandlerWrapper extends StatefulWidget {
  const PermissionHandlerWrapper({super.key});
  @override
  State<PermissionHandlerWrapper> createState() => _PermissionHandlerWrapperState();
}

class _PermissionHandlerWrapperState extends State<PermissionHandlerWrapper> {
  bool _isGranted = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkPermissions());
  }

  Future<void> _checkPermissions() async {
    Map<Permission, PermissionStatus> statuses = await [Permission.location, Permission.notification].request();
    if (statuses[Permission.location]!.isDenied || statuses[Permission.notification]!.isDenied) {
      if (mounted) _showPermissionDialog();
    } else {
      if (mounted) setState(() => _isGranted = true);
    }
  }

  void _showPermissionDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text("أذونات التشغيل"),
        content: const Text("يرجى السماح بالوصول للموقع والإشعارات لعمل التطبيق بشكل صحيح."),
        actions: [
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context); // إغلاق النافذة
              await [Permission.location, Permission.notification].request();
              // تحديث الحالة لتشغيل الواجهة
              if (mounted) setState(() => _isGranted = true); 
            },
            child: const Text("موافق"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // 🚀 عرض الداشبورد مباشرة بدون Navigator.push لتجنب الشاشة السوداء
    return _isGranted 
        ? const MainDashboardScreen() 
        : const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}
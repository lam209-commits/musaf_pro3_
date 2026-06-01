import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:musaf_pro/screens/main_dashboardF_screen.dart';
import 'package:provider/provider.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:permission_handler/permission_handler.dart'; 
import 'firebase_options.dart';

import 'package:musaf_pro/services/notification_service.dart';

import 'package:musaf_pro/providers/location_provider.dart';
import 'package:musaf_pro/data/repositories/firebase_zone_repository.dart';

import 'package:musaf_pro/screens/home_screen.dart' as caregiver_home;
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
import 'package:musaf_pro/screens/auth/patient_register_screen.dart';
import 'package:musaf_pro/screens/patient_home_screen.dart';
import 'package:musaf_pro/screens/health_vitals_screen.dart';
import 'package:musaf_pro/screens/medications_screen.dart';
import 'package:musaf_pro/screens/daily_medications_list_screen.dart';
// تأكدي من كتابة المسار الصحيح للملف حسب مجلدات مشروعك
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
        fontFamily: 'Almarai',
        primarySwatch: Colors.red,
        scaffoldBackgroundColor: Colors.white,
      ),
      home: const AppInitGate(),
      routes: {
        '/splash': (context) => const SplashScreen(),
        '/onboarding': (context) => const OnboardingScreen(),
        '/role_selection': (context) => const RoleSelectionScreen(),
        '/login': (context) => const LoginScreen(),
        '/register': (context) => const RegisterScreen(),
        '/patient_register': (context) => const PatientRegisterScreen(),
        '/pairing': (context) => const PairingCodeScreen(),
        '/health_data': (context) => const HealthDataScreen(),
        '/health_vitals': (context) => const HealthVitalsScreen(),
        '/medications': (context) => const MedicationsScreen(),
        '/daily_medications': (context) => const DailyMedicationsListScreen(),
        '/patient_home': (context) => const PatientHomeScreen(),
        '/home': (context) => const MainDashboardScreen(),
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

class AppInitGate extends StatelessWidget {
  const AppInitGate({super.key});
  @override
  Widget build(BuildContext context) {
    return const AuthGate();
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const SplashScreen();
        
        if (snapshot.hasData && snapshot.data != null) {
          return FutureBuilder<DocumentSnapshot>(
            future: FirebaseFirestore.instance.collection('users').doc(snapshot.data!.uid).get(),
            builder: (context, userSnapshot) {
              if (userSnapshot.connectionState == ConnectionState.waiting) return const SplashScreen();
              
              final data = userSnapshot.data?.data() as Map<String, dynamic>?;
              final String role = data?['role'] ?? 'patient';
              
              return role == 'caregiver' ? const PermissionHandlerWrapper() : const PatientHomeScreen();
            },
          );
        }
        return const OnboardingScreen();
      },
    );
  }
}

class PermissionHandlerWrapper extends StatefulWidget {
  const PermissionHandlerWrapper({super.key});
  @override
  State<PermissionHandlerWrapper> createState() => _PermissionHandlerWrapperState();
}

class _PermissionHandlerWrapperState extends State<PermissionHandlerWrapper> {
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
      _navigateToHome();
    }
  }

  // استبدل الدالة القديمة بهذه الدالة
  void _navigateToHome() {
    if (mounted) {
      // ننتقل إلى شاشة الحاوية التي تحتوي على الـ BottomNav
      Navigator.pushReplacement(
        context, 
        MaterialPageRoute(builder: (context) => const MainDashboardScreen()),
      );
    }
  }

  void _showPermissionDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text("أذونات التشغيل"),
        content: const Text("يرجى السماح بالوصول للموقع والإشعارات لعمل التطبيق."),
        actions: [
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await [Permission.location, Permission.notification].request();
              _navigateToHome();
            },
            child: const Text("موافق"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => const Scaffold(body: Center(child: CircularProgressIndicator()));
}
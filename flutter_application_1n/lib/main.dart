import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:permission_handler/permission_handler.dart'; 
import 'package:flutter_application_1n/data/repositories/firebase_zone_repository.dart';

import 'core/theme/app_colors.dart';
import 'core/theme/app_theme.dart';

import 'presentation/providers/location_provider.dart';

import 'presentation/screens/home_screen.dart';
import 'presentation/screens/map_screen.dart';
import 'presentation/screens/add_zone_screen.dart';
import 'presentation/screens/notifications_screen.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  runApp(
    MultiProvider(
      providers: [
ChangeNotifierProvider(
  create: (_) => LocationProvider(FirebaseZoneRepository()),    
),
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
      title: 'مُسْعِف - تتبع وحماية العائلة',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: 'Cairo',
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.primary,
          primary: AppColors.primary,
          secondary: AppColors.secondary,
          error: AppColors.error,
          surface: AppColors.background, // تم تعديل background إلى surface للـ Material 3
        ),
        scaffoldBackgroundColor: AppColors.background,
        appBarTheme: const AppBarTheme(
          backgroundColor: AppColors.surface,
          elevation: 0,
          centerTitle: true,
          titleTextStyle: TextStyle(
            color: AppColors.textPrimary,
            fontFamily: 'Cairo',
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
      ),
      locale: const Locale('ar', 'SA'),
      builder: (context, child) {
        return Directionality(
          textDirection: TextDirection.rtl, 
          child: child!,
        );
      },
      home: const PermissionHandlerWrapper(), 
      
      onGenerateRoute: (settings) {
        // فحص نوع البيانات المرسلة في الـ arguments لتجنب الـ Error
        final String patientId = settings.arguments is String ? settings.arguments as String : "user_123";
        
        switch (settings.name) {
          case '/home':
            return MaterialPageRoute(builder: (context) => const HomeScreen());
          case '/map':
            return MaterialPageRoute(builder: (context) => MapScreen(patientId: patientId));
          case '/add_zone':
            return MaterialPageRoute(builder: (context) => AddZoneScreen(patientId: patientId));
          case '/notifications':
            return MaterialPageRoute(builder: (context) => NotificationScreen(patientId: patientId));
          default:
            return MaterialPageRoute(builder: (context) => const HomeScreen());
        }
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
    // تأخير طفيف لضمان استقرار الشاشة قبل فحص الأذونات
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkPermissions());
  }

  Future<void> _checkPermissions() async {
    // طلب الأذونات مباشرة أفضل من فحص الحالة فقط في البداية
    Map<Permission, PermissionStatus> statuses = await [
      Permission.location,
      Permission.notification,
    ].request();

    if (statuses[Permission.location]!.isDenied || statuses[Permission.notification]!.isDenied) {
      if (mounted) _showPermissionDialog();
    } else {
      _checkUserDataAndNavigate();
    }
  }

  Future<void> _checkUserDataAndNavigate() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        final doc = await FirebaseFirestore.instance
            .collection('families')
            .doc(user.uid)
            .get();

        if (mounted) {
          if (doc.exists) {
            Navigator.pushReplacementNamed(context, '/home');
          } else {
            Navigator.pushReplacementNamed(context, '/family_setup');
          }
        }
      } catch (e) {
        if (mounted) Navigator.pushReplacementNamed(context, '/home');
      }
    } else {
      if (mounted) Navigator.pushReplacementNamed(context, '/home');
    }
  }

  void _showPermissionDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.cardRadius)),
        title: const Icon(Icons.security_update_good, size: 60, color: AppColors.primary),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text("أذونات التشغيل",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: AppColors.textPrimary)),
            SizedBox(height: 12),
            Text(
              "لكي يعمل تتبع الموقع بدقة وتصلك تنبيهات الحماية في الوقت المناسب، يرجى السماح بالوصول للموقع والإشعارات.",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.grey, height: 1.5),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.all(10),
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                minimumSize: const Size(double.infinity, 50),
              ),
              onPressed: () async {
                Navigator.pop(context);
                await [Permission.location, Permission.notification].request();
                _checkUserDataAndNavigate();
              },
              child: const Text("موافق، ابدأ الآن", style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: AppColors.primary),
            SizedBox(height: 24),
            Text("جاري التحقق من البيانات...", 
              style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }
}
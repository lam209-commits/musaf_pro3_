import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../providers/location_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';

// المكونات المفصلة (Widgets) لضمان نظافة الكود (Clean Code)
import '../widgets/status_hero.dart';
import '../widgets/action_tile.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String currentPatientId = "user_123"; 
  // تثبيت اللون البنفسجي الموحد لهوية التطبيق الرسومية
  final Color primaryPurple = const Color(0xFF6C63FF);

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  /// تهيئة البيانات الأولية للتطبيق عند الدخول
  void _initializeData() {
    final user = FirebaseAuth.instance.currentUser;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        if (user != null) {
          setState(() => currentPatientId = user.uid);
        }
        final pro = context.read<LocationProvider>();
        
        // جلب البيانات الأساسية للمريض وتفعيل التتبع الحركي اللحظي
        pro.fetchPatientName(currentPatientId); 
        pro.startPatientTracking(currentPatientId);
        pro.loadSafeZones(currentPatientId);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: _buildModernAppBar(),
      body: Consumer<LocationProvider>(
        builder: (context, loc, child) {
          // منطق تحديد حالة الخطر بناءً على حالة الموقع الجغرافي
          bool isDanger = loc.status.contains("خارج") || loc.status.contains("⚠️");

          return RefreshIndicator(
            onRefresh: () async {
              await loc.loadSafeZones(currentPatientId);
              await loc.fetchPatientName(currentPatientId);
            },
            color: primaryPurple, // توحيد لون مؤشر التحديث
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. واجهة الحالة الرئيسية المحدثة (Status Section)
                  StatusHero(status: loc.status, isDanger: isDanger),

                  const SizedBox(height: 32),
                  _buildSectionTitle("الخدمات الأساسية"),
                  const SizedBox(height: 16),

                  // 2. قائمة لوحة التحكم والخدمات الأساسية الموحدة باللون البنفسجي مع التلميحات والمسميات الدقيقة
                  _buildActionList(loc.patientName),
                  
                  // مساحة أمان سفلية لضمان راحة التصميم أثناء السحب
                  const SizedBox(height: 25),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // --- مكونات واجهة المستخدم الفرعية (UI Components) ---

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontWeight: FontWeight.w800, 
        fontSize: 18, 
        fontFamily: 'Cairo',
        color: AppColors.textPrimary
      ),
    );
  }

  Widget _buildActionList(String pName) {
    String nameText = pName.isNotEmpty ? pName : 'التابع';

    return Column(
      children: [
        // 1. تلميح وإعداد زر التتبع الجغرافي
        Tooltip(
          message: "فتح الخريطة لمراقبة موقع $nameText الجغرافي ولحظياً",
          textStyle: const TextStyle(fontFamily: 'Cairo', color: Colors.white, fontSize: 12),
          decoration: BoxDecoration(color: primaryPurple.withOpacity(0.95), borderRadius: BorderRadius.circular(10)),
          waitDuration: const Duration(milliseconds: 400), // يظهر سريعاً عند الضغط المطول
          child: HomeActionTile(
            title: "تتبع $nameText الآن", 
            icon: Icons.map_rounded,
            color: primaryPurple,
            onTap: () => Navigator.pushNamed(context, '/map', arguments: currentPatientId),
          ),
        ),
        const SizedBox(height: 12),
        
        // 2. تلميح وإعداد زر إدارة النطاقات الجغرافية الآمنة
        Tooltip(
          message: "إضافة أو حذف السياج الجغرافي وتفعيل نطاقات الأمان لـ $nameText",
          textStyle: const TextStyle(fontFamily: 'Cairo', color: Colors.white, fontSize: 12),
          decoration: BoxDecoration(color: primaryPurple.withOpacity(0.95), borderRadius: BorderRadius.circular(10)),
          child: HomeActionTile(
            title: "إدارة مناطق الأمان",
            icon: Icons.gpp_good_rounded,
            color: primaryPurple,
            onTap: () => Navigator.pushNamed(context, '/add_zone', arguments: currentPatientId),
          ),
        ),
        const SizedBox(height: 12),
        
        // 3. تلميح وإعداد زر محرك الطوارئ لجرعات الأدوية الفائتة
        Tooltip(
          message: "عرض الإشعارات الفورية في حال تأخر $nameText عن أخذ جرعة الدواء في وقتها المحدد",
          textStyle: const TextStyle(fontFamily: 'Cairo', color: Colors.white, fontSize: 12),
          decoration: BoxDecoration(color: primaryPurple.withOpacity(0.95), borderRadius: BorderRadius.circular(10)),
          child: HomeActionTile(
            title: "تنبيهات تأخير الأدوية", // تم التحديث ليعبر عن الهوية الحركية للميزة
            icon: Icons.notification_important_rounded, // أيقونة تحذيرية تعبر عن خطورة التأخير الزمني
            color: primaryPurple,
            onTap: () => Navigator.pushNamed(context, '/medications', arguments: currentPatientId),
          ),
        ),
      ],
    );
  }

  PreferredSizeWidget _buildModernAppBar() {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      centerTitle: true,
      title: Text(
        "مُسْعِف", 
        style: TextStyle(color: primaryPurple, fontWeight: FontWeight.w900, fontSize: 24, fontFamily: 'Cairo')
      ),
      leading: IconButton(
        icon: const Icon(Icons.grid_view_rounded, color: AppColors.textPrimary),
        onPressed: () {},
      ),
      actions: [
        _buildNotificationBadge(),
        const SizedBox(width: 10),
      ],
    );
  }

  Widget _buildNotificationBadge() {
    return Consumer<LocationProvider>(
      builder: (context, loc, _) {
        bool hasDanger = loc.status.contains("خارج") || loc.status.contains("⚠️");
        return IconButton(
          onPressed: () => Navigator.pushNamed(context, '/notifications', arguments: currentPatientId),
          icon: Badge(
            isLabelVisible: hasDanger, // يظهر التنبيه الأحمر فقط في حالة الخطر الحقيقي
            backgroundColor: AppColors.error,
            child: const Icon(Icons.notifications_outlined, color: AppColors.textPrimary, size: 28),
          ),
        );
      },
    );
  }
}
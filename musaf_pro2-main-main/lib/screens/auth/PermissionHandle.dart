import 'package:flutter/material.dart';
import 'package:musaf_pro/core/theme/app_colors.dart';
import 'package:musaf_pro/screens/main_dashboardF_screen.dart';
import 'package:permission_handler/permission_handler.dart';

class PermissionHandlerWrapper extends StatefulWidget {
  final String userType;

  const PermissionHandlerWrapper({super.key, required this.userType});

  @override
  State<PermissionHandlerWrapper> createState() => _PermissionHandlerWrapperState();
}

class _PermissionHandlerWrapperState extends State<PermissionHandlerWrapper> {
  bool _isGranted = false;
  bool _hasError = false; // 👈 متغير جديد لإيقاف الدوران اللانهائي عند الرفض
  late Color themeColor;

  @override
  void initState() {
    super.initState();
    themeColor = widget.userType == "patient" 
        ? const Color(0xFFD2042D) 
        : AppColors.primary;      

    WidgetsBinding.instance.addPostFrameCallback((_) => _startPermissionFlow());
  }

  // 🔄 تسلسل طلب الأذونات الذكي والمستقل
  Future<void> _startPermissionFlow() async {
    setState(() => _hasError = false);

    // 1. طلب النشاط البدني (حتى لو رفض، نكمل للباقي)
    await _requestPermission(Permission.activityRecognition, 
        "يحتاج مسعف للوصول لنشاطك البدني لتحسين دقة التتبع وتوفير الطاقة.");

    // 2. طلب الإشعارات
    await _requestPermission(Permission.notification, 
        "يجب تفعيل الإشعارات لتبقى على اتصال مع عائلتك واستلام تنبيهات الطوارئ.");

    // 3. طلب الموقع (أثناء الاستخدام)
    bool locGranted = await _requestPermission(Permission.location, 
        "يعمل تطبيق مسعف بشكل صحيح فقط إذا كان بإمكانه الوصول إلى موقعك.");

    // 4. طلب الموقع طوال الوقت (مسموح فقط إذا وافق على الموقع العادي أولاً)
    if (locGranted) {
      await _requestPermission(Permission.locationAlways, 
          "لضمان عمل تنبيهات 'المناطق الآمنة' حتى والتطبيق مغلق، يرجى اختيار 'السماح طوال الوقت'.");
    }

    // 🛑 الفحص النهائي: هل الأذونات الأساسية (الموقع والإشعارات) متوفرة؟
    bool hasEssentials = await Permission.location.isGranted && 
                         await Permission.notification.isGranted;

    if (hasEssentials) {
      if (mounted) setState(() => _isGranted = true);
    } else {
      // ❌ إذا رفض الأذونات الأساسية، نوقف التحميل ونظهر نافذة الإعدادات
      if (mounted) {
        setState(() => _hasError = true);
        _showSettingsDialog();
      }
    }
  }

  Future<bool> _requestPermission(Permission permission, String message) async {
    PermissionStatus status = await permission.status;
    if (status.isGranted) return true;

    // إظهار نافذة الشرح الخاصة بك
    bool? proceed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => _buildCustomPreDialog(message),
    );

    if (proceed == true) {
      status = await permission.request();
    }
    return status.isGranted;
  }

  Widget _buildCustomPreDialog(String message) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: const BoxDecoration(
              color: Color(0xFFFFEAEA),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.priority_high_rounded, color: Colors.red, size: 35),
          ),
          const SizedBox(height: 20),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: 'Cairo',
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: Color(0xFF2D2D2D),
              height: 1.5,
            ),
          ),
          const SizedBox(height: 30),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: themeColor,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                elevation: 0,
              ),
              onPressed: () => Navigator.pop(context, true),
              child: const Text(
                "موافق",
                style: TextStyle(fontFamily: 'Cairo', color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showSettingsDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text("صلاحيات مفقودة ⚠️", style: TextStyle(fontFamily: 'Cairo', color: themeColor, fontWeight: FontWeight.bold)),
        content: const Text(
          "لم يتم منح التطبيق الصلاحيات الأساسية (الموقع والإشعارات). يرجى فتح الإعدادات وتفعيلها يدوياً لتتمكن من استخدام التطبيق.",
          style: TextStyle(fontFamily: 'Cairo', height: 1.5),
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: themeColor),
            onPressed: () {
              Navigator.pop(context);
              openAppSettings(); // يفتح إعدادات الهاتف
            },
            child: const Text("فتح الإعدادات", style: TextStyle(fontFamily: 'Cairo', color: Colors.white)),
          ),
        ],
      ),
    ).then((_) {
      // بعد عودة المستخدم من الإعدادات، نعيد فحص الأذونات تلقائياً
      _startPermissionFlow();
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isGranted) return const MainDashboardScreen();

    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (!_hasError) ...[
              CircularProgressIndicator(color: themeColor),
              const SizedBox(height: 25),
              Text(
                "تأمين الوصول للميزات الحيوية...",
                style: TextStyle(fontFamily: 'Cairo', color: Colors.grey.shade700, fontWeight: FontWeight.w600),
              ),
            ] else ...[
              Icon(Icons.gpp_maybe_rounded, size: 80, color: themeColor),
              const SizedBox(height: 20),
              Text(
                "التطبيق متوقف بسبب نقص الصلاحيات",
                style: TextStyle(fontFamily: 'Cairo', color: Colors.grey.shade800, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: themeColor),
                onPressed: _startPermissionFlow,
                child: const Text("إعادة المحاولة", style: TextStyle(fontFamily: 'Cairo', color: Colors.white)),
              )
            ]
          ],
        ),
      ),
    );
  }
}
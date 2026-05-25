import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../providers/location_provider.dart';

// استدعاء كارد الواجهة المشتركة (إذا قمتِ بعزلها) لضمان نظافة البنية
class NotificationScreen extends StatelessWidget {
  final String patientId;
  const NotificationScreen({super.key, required this.patientId});

  // تثبيت اللون البنفسجي لتوحيد هوية النظام
final Color primaryPurple = const Color(0xFF6C63FF);
  void _showDeleteAllConfirmation(BuildContext context, LocationProvider provider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("حذف السجل؟", textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
        content: const Text("هل أنت متأكد من مسح جميع التنبيهات؟", textAlign: TextAlign.right, style: TextStyle(fontFamily: 'Cairo')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("إلغاء", style: TextStyle(color: Colors.grey, fontFamily: 'Cairo')),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error, 
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
            ),
            onPressed: () {
              provider.clearAllAlerts(patientId);
              Navigator.pop(context);
            },
            child: const Text("حذف الكل", style: TextStyle(color: Colors.white, fontFamily: 'Cairo')),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final locProvider = Provider.of<LocationProvider>(context, listen: false);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text("سجل التنبيهات الحرجة", style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
        centerTitle: true,
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_sweep_outlined, color: AppColors.error, size: 28),
            onPressed: () => _showDeleteAllConfirmation(context, locProvider),
          ),
        ],
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: locProvider.getAlertsStream(patientId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator(color: primaryPurple));
          }

          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return _buildEmptyState(); // أو استدعاء الـ EmptyStateWidget المشتركة هنا
          }

          final alerts = snapshot.data!;

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            physics: const BouncingScrollPhysics(),
            itemCount: alerts.length,
            itemBuilder: (context, index) {
              final alert = alerts[index];
              return Dismissible(
                key: Key(alert['id']),
                // 👈 ضبط اتجاه السحب ليتوافق مع السحب الطبيعي لليد باللغة العربية
                direction: DismissDirection.startToEnd, 
                onDismissed: (_) => locProvider.removeAlert(patientId, alert['id']),
                background: _buildDismissBackground(),
                child: _buildNotificationItem(alert, locProvider),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildNotificationItem(Map<String, dynamic> alert, LocationProvider provider) {
    bool isRead = alert['is_read'] ?? false;
    Color alertColor = _getAlertColor(alert['type']);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(15),
        // البرواز الجانبي يعطي ترميزاً لونياً سريعاً لنوع الخطورة (HCI Color Coding)
        border: Border(right: BorderSide(color: alertColor, width: 5)),
        boxShadow: [
          BoxShadow(
            color: isRead ? Colors.transparent : Colors.black.withOpacity(0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          )
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: CircleAvatar(
          backgroundColor: alertColor.withOpacity(0.1),
          child: Icon(_getAlertIcon(alert['type']), color: alertColor, size: 22),
        ),
        title: Text(
          alert['message'] ?? 'تنبيه طوارئ جديد',
          style: TextStyle(
            fontWeight: isRead ? FontWeight.normal : FontWeight.bold,
            fontFamily: 'Cairo',
            fontSize: 14,
            color: isRead ? Colors.black54 : Colors.black,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            alert['time_string'] ?? '',
            style: const TextStyle(fontSize: 11, color: Colors.grey, fontFamily: 'Cairo'),
          ),
        ),
        onTap: () => provider.markAsRead(patientId, alert['id']),
      ),
    );
  }

  // --- دوال الترميز البصري الذكي المحدثة لتشمل نوع الأدوية الجديد ---

  Color _getAlertColor(String? type) {
    if (type == 'exit') return AppColors.error;          // أحمر للخروج الجغرافي الخطر
    if (type == 'battery') return Colors.orange;         // برتقالي لانخفاض البطارية حركياً
    if (type == 'medication_delay') return primaryPurple; // بنفسجي موحد لتأخير الأدوية الحرجة
    if (type == 'accident_fall') return Colors.red.shade900; // أحمر داكن لحوادث السقوط المفاجئة
    return primaryPurple;
  }

  IconData _getAlertIcon(String? type) {
    if (type == 'exit') return Icons.warning_rounded;
    if (type == 'battery') return Icons.battery_alert_rounded;
    if (type == 'medication_delay') return Icons.notification_important_rounded; // أيقونة الأهمية الزمنية للدواء
    if (type == 'accident_fall') return Icons.personal_injury_rounded;           // أيقونة حادث السقوط
    return Icons.notifications_active_rounded;
  }

  Widget _buildDismissBackground() {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      alignment: Alignment.centerLeft, // تم الضبط لليسار ليتماشى مع سحب startToEnd العربي
      padding: const EdgeInsets.only(left: 20),
      decoration: BoxDecoration(
        color: Colors.redAccent, 
        borderRadius: BorderRadius.circular(15)
      ),
      child: const Row(
        children: [
          Icon(Icons.delete_forever_rounded, color: Colors.white, size: 26),
          SizedBox(width: 8),
          Text("حذف التنبيه", style: TextStyle(color: Colors.white, fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.notifications_none_rounded, size: 70, color: Colors.grey.shade300),
          const SizedBox(height: 12),
          const Text(
            "سجل التنبيهات فارغ تماماً", 
            style: TextStyle(color: Colors.grey, fontFamily: 'Cairo', fontSize: 14, fontWeight: FontWeight.bold)
          ),
        ],
      ),
    );
  }
}
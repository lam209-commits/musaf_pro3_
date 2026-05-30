import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../providers/location_provider.dart';

class FamilyAlertsScreen extends StatelessWidget {
  final String patientId;
  const FamilyAlertsScreen({super.key, required this.patientId});

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
    // جلب اللون الأساسي من ثيم التطبيق
    final themePrimaryColor = Theme.of(context).primaryColor;

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
            return Center(child: CircularProgressIndicator(color: themePrimaryColor));
          }

          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return _buildEmptyState();
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
                direction: DismissDirection.startToEnd, 
                onDismissed: (_) => locProvider.removeAlert(patientId, alert['id']),
                background: _buildDismissBackground(),
                child: _buildNotificationItem(alert, locProvider, themePrimaryColor),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildNotificationItem(Map<String, dynamic> alert, LocationProvider provider, Color primaryColor) {
    bool isRead = alert['is_read'] ?? false;
    Color alertColor = _getAlertColor(alert['type'], primaryColor);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(15),
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
          child: Icon(_getAlertIcon(alert['type'], primaryColor), color: alertColor, size: 22),
        ),
        title: Text(
          alert['message'] ?? 'تنبيه طوارئ جديد',
          style: TextStyle(
            fontWeight: isRead ? FontWeight.normal : FontWeight.bold,
            fontFamily: 'Cairo',
            fontSize: 14,
            color: isRead ? Colors.black54 : Colors.black87,
          ),
        ),
        // تم التعديل حسب ملاحظتك لعرض التاريخ والوقت
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              // تم التغيير إلى time_string بناءً على الكود في ZoneRepository الذي أرسلته سابقاً
              // إذا كنت تستخدم date_time_string في قاعدة البيانات، استبدلها هنا
              alert['time_string'] ?? '', 
              style: const TextStyle(
                fontSize: 12,
                color: Colors.grey,
                fontFamily: 'Cairo',
              ),
            ),
          ],
        ),
        onTap: () => provider.markAsRead(patientId, alert['id']),
      ),
    );
  }

  // تم التعديل باستخدام Switch Case
  Color _getAlertColor(String? type, Color primaryColor) {
    switch (type) {
      case 'exit':
        return Colors.red;
      case 'entry':
        return Colors.green;
      case 'battery':
        return Colors.orange;
      case 'signal_loss': // تم إضافة فقدان الإشارة
        return const Color.fromARGB(255, 130, 126, 136);
      case 'medication_delay':
        return primaryColor;
      case 'accident_fall':
        return Colors.red.shade900;
      default:
        return primaryColor;
    }
  }

  // تم التعديل باستخدام Switch Case
  IconData _getAlertIcon(String? type, Color primaryColor) {
    switch (type) {
      case 'exit':
        return Icons.warning_rounded;
      case 'entry':
        return Icons.home_rounded; // تعديل ليتوافق مع الدخول
      case 'battery':
        return Icons.battery_alert_rounded;
      case 'signal_loss':
        return Icons.portable_wifi_off_rounded;
      case 'medication_delay':
        return Icons.notification_important_rounded;
      case 'accident_fall':
        return Icons.personal_injury_rounded;
      default:
        return Icons.notifications_active_rounded;
    }
  }

  Widget _buildDismissBackground() {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      alignment: Alignment.centerLeft, 
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
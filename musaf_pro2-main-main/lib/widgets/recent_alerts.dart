import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';

class RecentAlertsCard extends StatelessWidget {
  final bool isDanger;
  final String? title;
  final String? subtitle;

  const RecentAlertsCard({
    super.key,
    required this.isDanger,
    this.title,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
        border: Border.all(
          color: isDanger 
              ? AppColors.error.withOpacity(0.2) 
              : Colors.black.withOpacity(0.05),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Row(
        children: [
          // أيقونة الحالة مع خلفية دائرية ملونة
          CircleAvatar(
            radius: 25,
            backgroundColor: isDanger 
                ? AppColors.error.withOpacity(0.1) 
                : AppColors.success.withOpacity(0.1),
            child: Icon(
              isDanger ? Icons.location_off_rounded : Icons.location_on_rounded,
              color: isDanger ? AppColors.error : AppColors.success,
              size: 28,
            ),
          ),
          const SizedBox(width: 15),
          
          // نصوص التنبيه
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title ?? (isDanger ? "تجاوز المنطقة الآمنة" : "داخل النطاق الآمن"),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle ?? (isDanger 
                      ? "تم رصد المريض في منطقة غير معرفة" 
                      : "المريض حالياً في نطاق المنزل الآمن"),
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          
          // وقت التنبيه (اختياري)
          const Text(
            "الآن",
            style: TextStyle(fontSize: 10, color: Colors.grey),
          ),
        ],
      ),
    );
  }
}
import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';

class StatusHero extends StatelessWidget {
  final String status;
  final bool isDanger;

  const StatusHero({super.key, required this.status, required this.isDanger});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 500),
      width: double.infinity,
      padding: const EdgeInsets.all(25),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDanger 
              ? [const Color(0xFFFF5252), AppColors.error] 
              : [AppColors.primary, AppColors.primaryLight],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
        boxShadow: [isDanger ? AppTheme.dangerShadow : AppTheme.primaryShadow],
      ),
      child: Column(
        children: [
          Icon(
            isDanger ? Icons.warning_amber_rounded : Icons.check_circle_outline_rounded,
            color: Colors.white,
            size: 60,
          ),
          const SizedBox(height: 15),
          Text(
            isDanger ? "تنبيه هام!" : "الحالة الآن",
            style: const TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 5),
          Text(
            status,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}
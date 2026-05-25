import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

class HomeActionTile extends StatelessWidget {
  final String title;
  final IconData icon;
  final VoidCallback onTap;
  final Color color; // إضافة خاصية اللون للتحكم في هوية كل خدمة

  const HomeActionTile({
    super.key, 
    required this.title, 
    required this.icon, 
    required this.onTap,
    this.color = AppColors.primary, // قيمة افتراضية في حال لم يتم تمرير لون
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.05), // ظل خفيف بلون الخدمة لإضفاء لمسة جمالية
            blurRadius: 10, 
            offset: const Offset(0, 4)
          )
        ],
      ),
      child: ListTile(
        onTap: onTap,
        tileColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            // استخدام لون الخدمة بشفافية خفيفة للخلفية
            color: color.withOpacity(0.1), 
            borderRadius: BorderRadius.circular(12)
          ),
          child: Icon(icon, color: color), // أيقونة بلون الخدمة المرر
        ),
        title: Text(
          title, 
          style: const TextStyle(
            fontWeight: FontWeight.bold, 
            fontSize: 15,
            fontFamily: 'Cairo' // لضمان ظهور الخط العربي بشكل أكاديمي جميل
          )
        ),
        trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16, color: Colors.black26),
      ),
    );
  }
}
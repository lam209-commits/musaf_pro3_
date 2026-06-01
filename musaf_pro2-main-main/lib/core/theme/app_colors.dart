import 'package:flutter/material.dart';

class AppColors {
  // الألوان الأساسية
  static const Color primary = Color(0xFF2E7D32); 
  static const Color primaryLight = Color(0xFF81C784); 
  static const Color accent = Color(0xFFB7131A); 
  
  // ألوان الخلفيات والنصوص
  static const Color background = Color(0xFFF8F9FE);
  static const Color surface = Colors.white;
  static const Color textPrimary = Color(0xFF2D2D2D);
  static const Color textSecondary = Color(0xFF757575);
  
  // ألوان الحالات (الاستخدام الصحيح)
  static const Color success = Color(0xFF2E7D32); // أخضر للوضع السليم
  static const Color warning = Color(0xFFF57C00); // برتقالي للتحذير/جاري الاتصال
  static const Color error = Color(0xFFB7131A);   // أحمر للأخطاء/خارج النطاق
}
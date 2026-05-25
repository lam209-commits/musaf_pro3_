import 'package:flutter/material.dart';
import 'app_colors.dart';

class AppTheme {
  static const double cardRadius = 24.0;
  static const double sidePadding = 20.0;

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      // في Material 3، نستخدم ColorScheme بدلاً من primaryColor المنفرد
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        primary: AppColors.primary,
        onPrimary: Colors.white,
        surface: AppColors.surface,
        error: AppColors.error,
      ),
      scaffoldBackgroundColor: AppColors.background,
      fontFamily: 'Cairo', 
      
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: AppColors.textPrimary),
        titleTextStyle: TextStyle(
          color: AppColors.primary,
          fontWeight: FontWeight.w900,
          fontSize: 22,
          fontFamily: 'Cairo',
        ),
      ),

      // التعديل هنا: اسم الخاصية cardTheme ونوعها CardTheme
     cardTheme: CardThemeData(
  color: AppColors.surface,
  elevation: 0, 
  shape: RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(cardRadius),
  ),
),

      textTheme: const TextTheme(
        displayLarge: TextStyle(
          color: AppColors.textPrimary, 
          fontWeight: FontWeight.bold, 
          fontSize: 22,
          fontFamily: 'Cairo',
        ),
        bodyMedium: TextStyle(
          color: AppColors.textSecondary, 
          fontSize: 14,
          fontFamily: 'Cairo',
        ),
      ),
      
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          minimumSize: const Size(double.infinity, 55),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 0,
          textStyle: const TextStyle(
            fontFamily: 'Cairo',
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      ),
    );
  }

  // الظلال
  static BoxShadow get primaryShadow => BoxShadow(
    color: AppColors.primary.withOpacity(0.15),
    blurRadius: 25,
    offset: const Offset(0, 10),
  );

  static BoxShadow get dangerShadow => BoxShadow(
    color: AppColors.error.withOpacity(0.2),
    blurRadius: 25,
    offset: const Offset(0, 10),
  );
}
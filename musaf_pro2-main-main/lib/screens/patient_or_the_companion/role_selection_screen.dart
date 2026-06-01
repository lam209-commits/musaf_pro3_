import 'package:flutter/material.dart';

import 'package:musaf_pro/widgets/custom_button.dart';

class RoleSelectionScreen extends StatelessWidget {
  const RoleSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    const Color primaryRed = Color(0xFFB7131A);

    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 30),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.health_and_safety, size: 100, color: primaryRed),
              const SizedBox(height: 30),
              const Text(
                "مرحباً بك في مُسعف",
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
              ),
              const Text(
                "الرجاء اختيار نوع الحساب للبدء",
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
              const SizedBox(height: 50),

              // 🚀 زر "أنا مريض" بالودجت المطور (أحمر + أيقونة)
              CustomButton(
                text: "أنا مريض",
                icon: Icons.person,
                backgroundColor: primaryRed,
                height: 65, // الارتفاع المخصص لتصميمك
                onPressed: () => Navigator.pushNamed(
                  context,
                  '/register',
                  arguments: 'patient',
                ),
              ),

              const SizedBox(height: 20),

              // 🚀 زر "أنا مرافق" بالودجت المطور (أسود + أيقونة)
              CustomButton(
                text: "أنا مرافق",
                icon: Icons.family_restroom,
                backgroundColor: Color(0xFF2E7D32),
                height: 65,
                onPressed: () => Navigator.pushNamed(
                  context,
                  '/register',
                  arguments: 'caregiver',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

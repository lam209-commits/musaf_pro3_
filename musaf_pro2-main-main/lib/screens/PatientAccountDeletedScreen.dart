import 'package:flutter/material.dart';

class PatientAccountDeletedScreen extends StatelessWidget {
  const PatientAccountDeletedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white, // شاشة بيضاء
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(30.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.person_remove_alt_1_rounded, size: 100, color: Colors.grey),
              const SizedBox(height: 20),
              const Text(
                "لقد قام التابع بحذف حسابه نهائياً",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, fontFamily: 'Cairo'),
              ),
              const SizedBox(height: 15),
              const Text(
                "لم يعد بإمكانك متابعة هذا الحساب. سيتم إلغاء الربط تلقائياً.",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Colors.grey, fontFamily: 'Cairo'),
              ),
              const SizedBox(height: 40),
              ElevatedButton(
                onPressed: () {
                  // العودة لشاشة اختيار الدور أو تسجيل الدخول
                  Navigator.pushNamedAndRemoveUntil(context, '/role_selection', (route) => false);
                },
                child: const Text("العودة للرئيسية", style: TextStyle(fontFamily: 'Cairo')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
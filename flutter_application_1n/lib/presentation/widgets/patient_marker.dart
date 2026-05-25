// lib/presentation/widgets/patient_marker.dart
import 'package:flutter/material.dart';

class PatientMarker extends StatelessWidget {
  final bool isDanger;
  const PatientMarker({super.key, required this.isDanger});

  @override
  Widget build(BuildContext context) {
    const Color primaryPurple = Color(0xFF6C63FF);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: isDanger ? Colors.red : Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: const [BoxShadow(blurRadius: 5, color: Colors.black26)],
          ),
          child: Text(
            isDanger ? "⚠️ خارج النطاق" : "موقع المريض",
            style: TextStyle(
              fontSize: 11, 
              fontWeight: FontWeight.bold, 
              color: isDanger ? Colors.white : Colors.black
            ),
          ),
        ),
        Icon(
          Icons.location_on_rounded, 
          color: isDanger ? Colors.red : primaryPurple, 
          size: 55
        ),
      ],
    );
  }
}
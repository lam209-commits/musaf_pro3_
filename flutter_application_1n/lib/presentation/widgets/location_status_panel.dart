// lib/presentation/widgets/location_status_panel.dart
import 'package:flutter/material.dart';

class LocationStatusPanel extends StatelessWidget {
  final String status;
  final bool isDanger;

  const LocationStatusPanel({
    super.key, 
    required this.status, 
    required this.isDanger
  });

  @override
  Widget build(BuildContext context) {
    const Color primaryPurple = Color(0xFF6C63FF);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 20)],
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: isDanger ? Colors.red.shade50 : primaryPurple.withOpacity(0.1),
            child: Icon(
              isDanger ? Icons.warning : Icons.check_circle, 
              color: isDanger ? Colors.red : primaryPurple
            ),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  "حالة التابع الآن", 
                  style: TextStyle(fontSize: 12, color: Colors.grey)
                ),
                Text(
                  status, 
                  style: TextStyle(
                    fontWeight: FontWeight.bold, 
                    fontSize: 16, 
                    color: isDanger ? Colors.red : Colors.black87
                  )
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
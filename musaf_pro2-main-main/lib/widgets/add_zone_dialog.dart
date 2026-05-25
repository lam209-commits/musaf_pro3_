// lib/presentation/widgets/add_zone_dialog.dart
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import '../providers/location_provider.dart';

class AddZoneDialog extends StatefulWidget {
  final LatLng point;
  final String patientId;

  const AddZoneDialog({
    super.key, 
    required this.point, 
    required this.patientId
  });

  @override
  State<AddZoneDialog> createState() => _AddZoneDialogState();
}

class _AddZoneDialogState extends State<AddZoneDialog> {
  String _selectedZoneType = "المنزل";
  double _currentRadius = 150.0;
  final TextEditingController _customNameController = TextEditingController();
  final List<String> _zoneOptions = ["المنزل", "المسجد", "العمل", "المدرسة", "بيت قريب", "أخرى"];

  @override
  Widget build(BuildContext context) {
    const Color primaryPurple = Color(0xFF6C63FF);

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      title: const Text("إضافة منطقة آمنة", textAlign: TextAlign.center),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              value: _selectedZoneType,
              decoration: InputDecoration(
                labelText: "نوع المكان",
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
              ),
              items: _zoneOptions.map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
              onChanged: (val) => setState(() => _selectedZoneType = val!),
            ),
            const SizedBox(height: 15),
            TextField(
              controller: _customNameController,
              textAlign: TextAlign.right,
              decoration: InputDecoration(
                hintText: "اسم مخصص (اختياري)",
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
              ),
            ),
            const SizedBox(height: 20),
            Text("القطر: ${_currentRadius.toInt()} متر"),
            Slider(
              value: _currentRadius,
              min: 50, max: 1000,
              activeColor: primaryPurple,
              onChanged: (val) => setState(() => _currentRadius = val),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context), 
          child: const Text("إلغاء")
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: primaryPurple),
          onPressed: () {
            String name = _customNameController.text.isNotEmpty 
                ? _customNameController.text 
                : _selectedZoneType;
            
            context.read<LocationProvider>().addNewSafeZone(
              patientId: widget.patientId,
              name: name,
              latitude: widget.point.latitude,
              longitude: widget.point.longitude,
              radius: _currentRadius,
            );
            
            Navigator.pop(context);
          },
          child: const Text("حفظ المنطقة", style: TextStyle(color: Colors.white)),
        ),
      ],
    );
  }
}
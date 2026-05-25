import 'package:flutter/material.dart';
import '../../domain/entities/safe_zone.dart';
import '../providers/location_provider.dart';

class ZoneCard extends StatelessWidget {
  final SafeZone zone; 
  final int index;
  final String patientId;
  final LocationProvider locProvider;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final Color primaryPurple;

  const ZoneCard({
    super.key,
    required this.zone,
    required this.index,
    required this.patientId,
    required this.locProvider,
    required this.onEdit,
    required this.onDelete,
    this.primaryPurple = const Color(0xFF6C63FF),
  });

  @override
  Widget build(BuildContext context) {
    bool isPatientInsideNow = zone.isActive && locProvider.currentZoneId == zone.id;

    return Dismissible(
      key: Key(zone.id + index.toString()),
      // 👈 تعديل الاتجاه: السحب من اليمين إلى اليسار (وهو الاتجاه الطبيعي في الواجهات العربية)
      direction: DismissDirection.startToEnd, 
      background: _buildDeleteBackground(),
      confirmDismiss: (direction) async {
        onDelete(); 
        return false; 
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 400),
        margin: const EdgeInsets.only(bottom: 15),
        decoration: BoxDecoration(
          color: zone.isActive ? const Color(0xFFFBFBFF) : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isPatientInsideNow 
                ? Colors.green.withOpacity(0.7) 
                : (zone.isActive ? primaryPurple.withOpacity(0.1) : Colors.grey.shade200),
            width: isPatientInsideNow ? 2.5 : 1, 
          ),
          boxShadow: [
            if (isPatientInsideNow)
              BoxShadow(
                color: Colors.green.withOpacity(0.15),
                blurRadius: 15,
                spreadRadius: 3,
              )
          ],
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onEdit, 
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Opacity(
              opacity: zone.isActive ? 1.0 : 0.6,
              child: Row(
                children: [
                  _buildIconIndicator(isPatientInsideNow, zone.isActive),
                  const SizedBox(width: 15),
                  _buildZoneDetails(zone.isActive),
                  Switch(
                    value: zone.isActive,
                    activeColor: primaryPurple,
                    onChanged: (val) => locProvider.toggleZoneStatus(index, patientId, val),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // --- دوال بناء الواجهة الفرعية المحدثة (Sub-Widgets) ---

  // 👈 تعديل المحاذاة والترتيب ليظهر النص والأيقونة في الجهة اليسرى المستهدفة بشكل منظم
  Widget _buildDeleteBackground() {
    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      padding: const EdgeInsets.symmetric(horizontal: 20),
      alignment: Alignment.centerLeft, // تثبيت المحاذاة يساراً
      decoration: BoxDecoration(
        color: Colors.redAccent,
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.start, // تبدأ من اليسار توازياً مع السحب لليمين
        children: [
          Icon(Icons.delete_sweep_rounded, color: Colors.white, size: 26),
          SizedBox(width: 10),
          Text(
            "حذف النطاق",
            style: TextStyle(fontFamily: 'Cairo', color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildIconIndicator(bool isInside, bool active) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isInside 
            ? Colors.green.withOpacity(0.1) 
            : (active ? primaryPurple.withOpacity(0.1) : Colors.grey.withOpacity(0.1)),
        borderRadius: BorderRadius.circular(15),
        border: isInside ? Border.all(color: Colors.green, width: 1.5) : null,
      ),
      child: Icon(
        _getIconForType(zone.name), 
        color: isInside ? Colors.green : (active ? primaryPurple : Colors.grey), 
        size: 28
      ),
    );
  }

  Widget _buildZoneDetails(bool active) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            zone.name, 
            style: TextStyle(
              fontWeight: FontWeight.bold, 
              fontSize: 16, 
              fontFamily: 'Cairo', 
              color: active ? Colors.black87 : Colors.grey
            )
          ),
          const SizedBox(height: 4),
          Text(
            "نطاق الأمان: ${zone.radius.toInt()} متر", 
            style: TextStyle(
              color: Colors.grey.shade600, 
              fontSize: 13, 
              fontFamily: 'Cairo'
            )
          ),
        ],
      ),
    );
  }

  IconData _getIconForType(String type) {
    final name = type.toLowerCase();
    if (name.contains('منزل') || name.contains('بيت')) return Icons.home_rounded;
    if (name.contains('مدرسة') || name.contains('جامعة')) return Icons.school_rounded;
    if (name.contains('حديقة') || name.contains('نادي')) return Icons.park_rounded;
    if (name.contains('مسجد')) return Icons.mosque_rounded;
    if (name.contains('مستشفى') || name.contains('عيادة')) return Icons.local_hospital_rounded;
    return Icons.location_on_rounded;
  }
}
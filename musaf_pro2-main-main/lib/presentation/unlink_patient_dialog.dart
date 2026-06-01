import 'package:flutter/material.dart';
import '../../domain/repositories/auth_repository.dart';
import 'package:musaf_pro/core/theme/app_colors.dart'; // تأكدي من المسار الصحيح

class UnlinkPatientDialog extends StatefulWidget {
  final String currentUserId;
  final String patientId;
  final AuthRepository authRepository;

  const UnlinkPatientDialog({
    super.key,
    required this.currentUserId,
    required this.patientId,
    required this.authRepository,
  });

  @override
  State<UnlinkPatientDialog> createState() => _UnlinkPatientDialogState();
}

class _UnlinkPatientDialogState extends State<UnlinkPatientDialog> {
  bool _isLoading = false;

  Future<void> _handleUnlink() async {
    setState(() => _isLoading = true);

    try {
      await widget.authRepository.unlinkPatientLogic(
        widget.currentUserId,
        widget.patientId,
      );

      if (mounted) {
        Navigator.of(context).pop(true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم فك الارتباط بنجاح ✅', style: TextStyle(fontFamily: 'Cairo')),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString(), style: const TextStyle(fontFamily: 'Cairo')),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(
        children: [
          Icon(Icons.link_off_rounded, color: AppColors.error, size: 28),
          const SizedBox(width: 10),
          const Text(
            'فك الارتباط',
            style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 18),
          ),
        ],
      ),
      content: const Text(
        'هل أنت متأكد من فك الارتباط بالمريض؟ لن تتمكن من تلقي التنبيهات أو تتبع الموقع بعد الآن.',
        style: TextStyle(fontFamily: 'Cairo', fontSize: 14, height: 1.5),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(false),
          child: const Text(
            'إلغاء',
            style: TextStyle(fontFamily: 'Cairo', color: Colors.grey, fontWeight: FontWeight.bold),
          ),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _handleUnlink,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.error, // استخدام اللون الأحمر من الثيم
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          child: _isLoading
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                )
              : const Text(
                  'تأكيد',
                  style: TextStyle(fontFamily: 'Cairo', color: Colors.white, fontWeight: FontWeight.bold),
                ),
        ),
      ],
    );
  }
}
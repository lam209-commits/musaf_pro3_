import 'package:flutter/material.dart';
import '../../domain/repositories/auth_repository.dart';

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
    setState(() {
      _isLoading = true;
    });

    try {
      await widget.authRepository.unlinkPatientLogic(
        widget.currentUserId,
        widget.patientId,
      );

      if (mounted) {
        Navigator.of(context).pop(true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Unlink Successful', 
              style: TextStyle(fontFamily: 'Cairo'),
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              e.toString(),
              style: const TextStyle(fontFamily: 'Cairo'),
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      title: const Row(
        children: [
          Icon(Icons.link_off_rounded, color: Colors.orange, size: 28),
          SizedBox(width: 10),
          Text(
            'Unlink Patient',
            style: TextStyle(
              fontFamily: 'Cairo',
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
        ],
      ),
      content: const Text(
        'Are you sure you want to unlink this patient? You will no longer receive alerts.',
        style: TextStyle(
          fontFamily: 'Cairo',
          fontSize: 14,
          height: 1.5,
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(false),
          child: const Text(
            'Cancel',
            style: TextStyle(
              fontFamily: 'Cairo',
              color: Colors.grey,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _handleUnlink,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.orange,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          child: _isLoading
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
              : const Text(
                  'Confirm',
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
        ),
      ],
    );
  }
}
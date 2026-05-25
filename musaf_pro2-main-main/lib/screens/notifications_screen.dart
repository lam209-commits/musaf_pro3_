import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  final Color musafRed = const Color(0xFFB7131A);

  // دالة تحديث حالة الدواء في الفايربيس (إخفاء الإشعار)
  Future<void> _markAsTaken(String docId) async {
    try {
      await FirebaseFirestore.instance
          .collection('medications')
          .doc(docId)
          .update({
            'lastTakenDate': DateTime.now(), // تسجيل وقت الأخذ
            'isTakenToday': true, // تغيير الحالة لإخفاء الإشعار
          });
    } catch (e) {
      debugPrint("Error updating medication: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    String? userId = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'التنبيهات الصحية',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('medications')
            .where('userId', isEqualTo: userId)
            // جلب الأدوية التي لم يتم الضغط على "علامة الصح" لها اليوم
            .where('isTakenToday', isEqualTo: false)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return _buildEmptyState("لا توجد تنبيهات عاجلة حالياً");
          }

          final now = DateTime.now();
          final incomingNotifications = snapshot.data!.docs.where((doc) {
            var data = doc.data() as Map<String, dynamic>;
            var timesData = data['times'];
            List times = (timesData is List)
                ? timesData
                : [timesData.toString()];

            for (var timeStr in times) {
              try {
                List<String> parts = timeStr.trim().split(':');
                int hour = int.parse(parts[0]);
                int minute = int.parse(parts[1]);

                final medTime = DateTime(
                  now.year,
                  now.month,
                  now.day,
                  hour,
                  minute,
                );

                // حساب الفرق بالدقائق
                int diff = medTime.difference(now).inMinutes;

                // يظهر قبل الموعد بـ 5 دقائق فقط
                if (diff >= -30 && diff <= 5) return true;
              } catch (e) {
                continue;
              }
            }
            return false;
          }).toList();

          if (incomingNotifications.isEmpty) {
            return _buildEmptyState("لا توجد تنبيهات نشطة الآن");
          }

          return ListView.builder(
            padding: const EdgeInsets.all(15),
            itemCount: incomingNotifications.length,
            itemBuilder: (context, index) {
              var med = incomingNotifications[index];
              var data = med.data() as Map<String, dynamic>;

              return Card(
                elevation: 4,
                shadowColor: Colors.black12,
                margin: const EdgeInsets.only(bottom: 15),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.all(15),
                  leading: const Icon(
                    Icons.notifications_active,
                    color: Colors.red,
                    size: 40,
                  ),
                  title: Text(
                    'حان وقت: ${data['medName']}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                    textAlign: TextAlign.right,
                  ),
                  subtitle: const Text(
                    'متبقي 5 دقائق أو أقل.. اضغط علامة الصح عند أخذ الجرعة',
                    textAlign: TextAlign.right,
                    style: TextStyle(fontSize: 12),
                  ),
                  // أيقونة "علامة صح"
                  trailing: IconButton(
                    icon: const Icon(
                      Icons.check_circle,
                      color: Colors.green,
                      size: 35,
                    ),
                    onPressed: () => _markAsTaken(med.id),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildEmptyState(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.check_circle_outline,
            size: 80,
            color: Colors.green.withOpacity(0.3),
          ),
          const SizedBox(height: 15),
          Text(
            message,
            style: const TextStyle(color: Colors.grey, fontSize: 16),
          ),
        ],
      ),
    );
  }
}
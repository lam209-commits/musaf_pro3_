import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  final Color musafRed = const Color(0xFFB7131A);
  final Color musafTeal = const Color(0xFF006D77);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: musafRed,
        foregroundColor: Colors.white,
        title: const Text(
          'الإعدادات',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            // --- قسم الحساب الشخصي ---
            _buildSectionTitle('الحساب الشخصي'),
            _buildSettingsTile(
              icon: Icons.person_outline,
              title: 'تعديل الملف الشخصي',
              subtitle: 'تحديث اسمك، البريد الإلكتروني، وكلمة المرور',
              onTap: () {
                debugPrint("فتح تعديل الملف الشخصي");
              },
            ),
            _buildSettingsTile(
              icon: Icons.supervisor_account_outlined,
              title: 'إدارة المرافقين',
              subtitle: 'التحكم بالأشخاص المرتبطين بحسابك',
              onTap: () {
                debugPrint("فتح إدارة المرافقين");
              },
            ),

            const SizedBox(height: 25),

            // --- قسم الإعدادات الطبية ---
            _buildSectionTitle('الإعدادات الطبية'),
            _buildSettingsTile(
              icon: Icons.medical_information_outlined,
              title: 'الملف الطبي السريع',
              subtitle: 'تحديث فصيلة الدم، الحساسية، والأمراض المزمنة',
              onTap: () {
                debugPrint("فتح الملف الطبي");
              },
            ),

            const SizedBox(height: 25),

            // --- قسم عام ---
            _buildSectionTitle('عام'),
            _buildSettingsTile(
              icon: Icons.info_outline_rounded,
              title: 'حول تطبيق مُسعف',
              subtitle: 'الإصدار، فريق العمل، ورؤية التطبيق',
              onTap: () {
                debugPrint("فتح حول التطبيق");
              },
            ),

            const SizedBox(height: 40),

            // --- زر تسجيل الخروج ---
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: musafRed,
                  elevation: 0,
                  side: BorderSide(color: musafRed, width: 2),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                ),
                icon: const Icon(Icons.logout, size: 24),
                label: const Text(
                  'تسجيل الخروج',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                onPressed: () async {
                  // نافذة تأكيد قبل الخروج
                  _showLogoutDialog(context);
                },
              ),
            ),

            const SizedBox(height: 30),
            // توقيع التطبيق تحت
            Center(
              child: Text(
                'مُسعف V 1.0.0\nصُنع بحب من أجل سلامتك',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // دالة مساعدة لتنسيق عناوين الأقسام
  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15, right: 5),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: musafTeal,
        ),
      ),
    );
  }

  // دالة مساعدة لبناء أزرار الإعدادات بشكل موحد وأنيق
  Widget _buildSettingsTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
        trailing: Icon(icon, color: musafRed, size: 28),
        title: Text(
          title,
          textAlign: TextAlign.right,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        subtitle: Text(
          subtitle,
          textAlign: TextAlign.right,
          style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
        ),
        leading: Icon(
          Icons.arrow_back_ios_new,
          color: Colors.grey.shade400,
          size: 16,
        ),
      ),
    );
  }

  // نافذة تأكيد تسجيل الخروج
  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('تسجيل الخروج', textAlign: TextAlign.right),
        content: const Text(
          'هل أنت متأكد أنك تريد تسجيل الخروج من حسابك؟',
          textAlign: TextAlign.right,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: musafRed,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () async {
              Navigator.pop(context); // إغلاق النافذة
              await FirebaseAuth.instance.signOut();
              if (context.mounted) {
                // توجيه المستخدم لشاشة البداية
                Navigator.pushReplacementNamed(context, '/');
              }
            },
            child: const Text(
              'نعم، خروج',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}
import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';

class EmailService {
  // بيانات حسابك الموثق والكود السري
  static const String _userEmail = 'hdbaslwm25@gmail.com';
  static const String _appPassword = 'iujd pact pptf figq';

  // 1. دالة إرسال كود المرافق
  static Future<void> sendPairingCode({
    required String toEmail,
    required String pairingCode,
  }) async {
    final smtpServer = gmail(_userEmail, _appPassword);

    final message = Message()
      ..from = const Address(_userEmail, 'تطبيق مُسعف')
      ..recipients.add(toEmail)
      ..subject = 'كود الربط لمشروع مُسعف 🎉'
      ..text = 'مرحباً\n\nكود الربط الخاص بك هو: $pairingCode\n\nيرجى استخدامه لإتمام عملية الربط في التطبيق\n\nشكراً لك\nفريق مُسعف';

    try {
      await send(message, smtpServer);
      print('✅ تم إرسال كود المرافق بنجاح!');
    } catch (e) {
      print('❌ فشل إرسال كود المرافق: $e');
      // 🚀 إجبار الكود على إظهار الخطأ لكي تتراجع شاشة التسجيل ولا تنشئ حساباً وهمياً
      throw Exception('تعذر إرسال كود المرافق. تأكد من أن البريد حقيقي ويعمل'); 
    }
  }

  // 2. دالة إرسال كود المريض
  static Future<void> sendPatientVerificationCode({
    required String toEmail,
    required String verificationCode,
  }) async {
    // 🚀 إضافة تأخير بسيط (ثانية ونصف) لتجنب حظر Gmail للإرسال المتتالي السريع
    await Future.delayed(const Duration(milliseconds: 1500));

    final smtpServer = gmail(_userEmail, _appPassword);

    final message = Message()
      ..from = const Address(_userEmail, 'تطبيق مُسعف')
      ..recipients.add(toEmail) 
      ..subject = 'كود التحقق من بريدك الإلكتروني - مُسعف 🛡️'
      ..text = 'مرحباً\n\nأهلاً بك في تطبيق مُسعف\n\nكود التحقق الخاص بك هو: $verificationCode\n\nيرجى إدخال هذا الكود في التطبيق لتأكيد حسابك والبدء بإعداد ملفك الصحي\n\nنتمنى لك دوام الصحة والعافية،\nفريق مُسعف';

    try {
      await send(message, smtpServer);
      print('✅ تم إرسال كود التحقق للمريض بنجاح!');
    } catch (e) {
      print('❌ فشل إرسال كود تحقق المريض: $e');
      // 🚀 إجبار الكود على رمي الخطأ للتراجع
      throw Exception('تعذر إرسال كود المريض تأكد من أن البريد حقيقي ويعمل'); 
    }
  }
}
// lib/services/fcm_service.dart

import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:googleapis_auth/auth_io.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

class FcmService {
  // اسم مشروعك في فايربيس (تأكدنا منه من ملف الـ JSON)
  static const String _projectId = 'musaf-62fb2';

  static Future<void> sendPushMessage({
    required String familyToken,
    required String title,
    required String body,
    required String type,
  }) async {
    try {
      // 1. قراءة مفتاح فايربيس السري من مجلد assets
      final String jsonString = await rootBundle.loadString('assets/service_account.json');
      final serviceAccount = ServiceAccountCredentials.fromJson(jsonString);
      
      // 2. طلب صلاحية إرسال الإشعارات من جوجل
      final scopes = ['https://www.googleapis.com/auth/firebase.messaging'];
      final client = await clientViaServiceAccount(serviceAccount, scopes);
      
      // 3. رابط الإرسال الخاص بـ Firebase API V1
      final Uri url = Uri.parse('https://fcm.googleapis.com/v1/projects/$_projectId/messages:send');

      // 4. تجهيز هيكل الإشعار ليطابق متطلبات Firebase الجديدة
      final Map<String, dynamic> payload = {
        'message': {
          'token': familyToken, // توكن جهاز العائلة
          'notification': {
            'title': title,
            'body': body,
          },
          'data': {
            'click_action': 'FLUTTER_NOTIFICATION_CLICK',
            'type': type, // نوع التنبيه (سقوط، زر طوارئ... الخ)
          }
        }
      };

      // 5. إرسال الطلب (Post Request)
      final response = await client.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      );

      // إغلاق الاتصال بعد الانتهاء
      client.close();

      // 6. التحقق من النتيجة للطباعة في الـ Console
      if (response.statusCode == 200) {
        debugPrint('✅ تم إرسال الإشعار السحابي بنجاح لجهاز العائلة!');
      } else {
        debugPrint('❌ فشل إرسال الإشعار: ${response.body}');
      }
    } catch (e) {
      debugPrint('❌ حدث خطأ برمجي أثناء إرسال الإشعار: $e');
    }
  }
}
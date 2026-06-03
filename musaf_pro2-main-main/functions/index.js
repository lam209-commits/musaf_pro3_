
const functions = require("firebase-functions");
const admin = require("firebase-admin");

admin.initializeApp();

exports.sendAlertNotification = functions.firestore
  .document("patients/{patientId}/alerts/{alertId}")
  .onCreate(async (snap, context) => {
    // 1. جلب بيانات التنبيه الجديد
    const alertData = snap.data();
    const patientId = context.params.patientId;

    const title = alertData.title || "تنبيه جديد";
    const message = alertData.message || "يوجد تحديث لحالة المريض";

    try {
      // 2. جلب مستند المريض لمعرفة من هو المرافق (caregiverId)
      const patientDoc = await admin.firestore().collection("patients").doc(patientId).get();
      
      if (!patientDoc.exists) {
        console.log("المريض غير موجود");
        return null;
      }

      const caregiverId = patientDoc.data().caregiverId;

      if (!caregiverId) {
        console.log("لا يوجد مرافق مرتبط بهذا المريض");
        return null;
      }

      // 3. جلب مستند المرافق للحصول على fcmToken
      const caregiverDoc = await admin.firestore().collection("users").doc(caregiverId).get();
      
      if (!caregiverDoc.exists) {
        console.log("حساب المرافق غير موجود");
        return null;
      }

      const fcmToken = caregiverDoc.data().fcmToken;

      if (!fcmToken) {
        console.log("المرافق لا يملك FCM Token مسجل");
        return null;
      }

      // 4. تجهيز وإرسال الإشعار
      const payload = {
        token: fcmToken,
        notification: {
          title: title,
          body: message,
        },
        data: {
          click_action: "FLUTTER_NOTIFICATION_CLICK",
          alertType: alertData.type || "general",
          patientId: patientId,
        },
      };

      // إرسال الإشعار
      const response = await admin.messaging().send(payload);
      console.log("تم إرسال الإشعار بنجاح:", response);

      return null;

    } catch (error) {
      console.error("حدث خطأ أثناء إرسال الإشعار:", error);
      return null;
    }
  });

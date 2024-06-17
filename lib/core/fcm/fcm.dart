import 'package:firebase_messaging/firebase_messaging.dart';

class FCM {
  final messaging = FirebaseMessaging.instance;
  Future<void> initFCM() async {
    await messaging.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );

    await messaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );
  }

  Future<void> setFCM() async {
    var fcmToken = await messaging.getToken();
    print('FCM $fcmToken');
  }
}

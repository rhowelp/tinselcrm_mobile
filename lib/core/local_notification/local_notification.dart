import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationPlugin {
  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

  Future<void> initializeNotifications() async {
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'getNotification', // id
      'High Importance Notifications', // description
      importance: Importance.max,
      playSound: true,
      showBadge: true,
    );

    final localNotificationPlugin = _flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

    if (localNotificationPlugin != null) {
      localNotificationPlugin.createNotificationChannel(channel);
    }

    await _flutterLocalNotificationsPlugin.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@drawable/ic_notification'),
        iOS: DarwinInitializationSettings(
          defaultPresentAlert: true,
          defaultPresentBadge: true,
          defaultPresentSound: true,
          requestAlertPermission: true,
          requestBadgePermission: true,
          requestSoundPermission: true,
        ),
      ),
    );
  }

////// show notification
  Future showNotification({required String title, required String body, String payload = ''}) async {
    var androidDetails = const AndroidNotificationDetails(
      "GetNotification",
      "TinselCRM",
      importance: Importance.max,
      priority: Priority.max,
      fullScreenIntent: true,
      icon: '@drawable/ic_notification',
      visibility: NotificationVisibility.public,
      showWhen: true,
      autoCancel: true,
      playSound: true,
      enableVibration: true,
    );

    var iOSDetails = const DarwinNotificationDetails(
      presentSound: true,
      presentAlert: true,
      presentBadge: true,
    );
    print("message $title $body");

    var generalNotificationDetails = NotificationDetails(android: androidDetails, iOS: iOSDetails);

    await _flutterLocalNotificationsPlugin.show(0, title, body, generalNotificationDetails, payload: payload);
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:tinselcrm_mobile/app/app.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import 'package:firebase_core/firebase_core.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:tinselcrm_mobile/firebase_options.dart';

final userScripts = <UserScript>[];

Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  if (message.notification != null) {
    print('_firebaseMessagingBackgroundHandler ${message.toMap()}');
    // localNotification.showNotification(
    //   title: message.notification?.title ?? "",
    //   body: message.notification?.body ?? "",
    //   payload: '',
    // );
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  tz.initializeTimeZones();
  
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  runApp(const App());
}

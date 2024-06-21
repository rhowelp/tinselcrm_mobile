import 'dart:developer';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:tinselcrm_mobile/core/services/api_service.dart';

class ApiRepository {
  final api = ApiService.create();
  Future<void> saveFCM({required String id}) async {
    final token = await FirebaseMessaging.instance.getToken();
    final body = {
      "id": id,
      "fcm": token,
    };

    final response = await api.saveFCM(body);
    if (response.isSuccessful) {
      log('response >>>>> ${response.body}');
    }
  }
}

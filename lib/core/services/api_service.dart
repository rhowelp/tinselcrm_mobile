import 'package:chopper/chopper.dart';
import 'package:flutter/foundation.dart';
import 'package:tinselcrm_mobile/core/interceptors/token_interceptor.dart';

part 'api_service.chopper.dart';

@ChopperApi(baseUrl: 'https://dev2.tinselcrm.com/api')
abstract class ApiService extends ChopperService {
  static ApiService create() {
    final client = ChopperClient(
      converter: const JsonConverter(),
      interceptors: [TokenInterceptor(showLogs: kDebugMode)],
    );

    return _$ApiService(client);
  }

  @Post(path: '/auth/login')
  Future<Response<dynamic>> login(@Body() Map<String, dynamic> body);

  @Post(path: '/auth/fcm')
  Future<Response<dynamic>> saveFCM(@Body() Map<String, dynamic> body);
}
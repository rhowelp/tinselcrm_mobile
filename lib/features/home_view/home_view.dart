// ignore_for_file: use_build_context_synchronously, lines_longer_than_80_chars, avoid_print

import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:tinselcrm_mobile/core/local_notification/local_notification.dart';
import 'package:tinselcrm_mobile/main.dart';
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class HomePageView extends StatefulWidget {
  const HomePageView({super.key});

  @override
  State<HomePageView> createState() => _HomePageViewState();
}

class _HomePageViewState extends State<HomePageView> {
  final GlobalKey webViewKey = GlobalKey();
  WebSocketChannel? _channel;
  InAppWebViewController? webViewController;
  final _cookieManager = CookieManager.instance();
  bool _isConnected = false;
  double progress = 0;

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
  final localNotification = NotificationPlugin();
  bool notificationsEnabled = false;

  void connectToWebSocket(String sessionId) async {
    try {
      _channel = IOWebSocketChannel.connect(
        'wss://app.tinselcrm.com/webSocketServer',
        headers: {
          'Cookie': 'sessionId=$sessionId',
        },
      );
      try {
        await _channel!.ready;
      } on SocketException catch (e) {
        debugPrint('=====> SocketException $e');
      } on WebSocketChannelException catch (e) {
        debugPrint('=====> WebSocketChannelException $e');
      }
      _channel!.stream.listen(
        (message) {
          final notification = json.decode(message) as Map<String, dynamic>;
          localNotification.showNotification(
            title: notification['title'],
            body: notification['message'],
          );

          debugPrint('message=====> Received message: $message');
        },
        onDone: () {
          debugPrint('onDone=====> Connection Closed');
        },
        onError: (error) {
          debugPrint('onError=====> ERROR $error');
        },
      );
    } catch (e) {
      debugPrint('=====> Error connecting to WebSocket: $e');
    }
  }

  Future<void> getCookiesData(WebUri url) async {
    final cookies = await _cookieManager.getCookies(url: url);
    // debugPrint('COOKIE ${cookies.map((e) => e.toJson()).toList()}');
    final sessionId = cookies.firstWhere((cookie) => cookie.name == 'sessionId').value;

    setState(() {
      if (sessionId != null && !_isConnected) {
        // Connect to WebSocket with sessionId token
        debugPrint('=======> Connecting to WebSocket...');
        connectToWebSocket(sessionId);
      }
      _isConnected = true;
      debugPrint('=======> Connected: $_isConnected');
    });
  }

  @override
  initState() {
    super.initState();
    _isAndroidPermissionGranted();
    _requestPermissions();
    localNotification.initializeNotifications();
  }

  final webStorageManager = WebStorageManager.instance();
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        actions: <Widget>[
          IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              if (webViewController != null) {
                webViewController!.goBack();
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.arrow_forward),
            onPressed: () {
              if (webViewController != null) {
                webViewController!.goForward();
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              if (webViewController != null) {
                webViewController!.reload();
              }
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            child: progress < 1.0
                ? Padding(
                    padding: const EdgeInsets.all(2),
                    child: LinearProgressIndicator(value: progress),
                  )
                : Container(),
          ),
          Expanded(
            child: InAppWebView(
              key: webViewKey,
              initialUserScripts: UnmodifiableListView(userScripts),
              initialSettings: InAppWebViewSettings(
                useShouldOverrideUrlLoading: true,
                mediaPlaybackRequiresUserGesture: false,
                allowsInlineMediaPlayback: true,
              ),
              initialUrlRequest: URLRequest(url: WebUri.uri(Uri.parse('https://app.tinselcrm.com/'))),
              onWebViewCreated: (InAppWebViewController controller) {
                webViewController = controller;
              },
              onLoadStart: (controller, url) {
                setState(() {
                  debugPrint('=======> Page started loading: $url');
                });
              },
              shouldOverrideUrlLoading: (controller, navigationAction) async {
                var uri = navigationAction.request.url;
                debugPrint('URI $uri');
                return NavigationActionPolicy.ALLOW;
              },
              onNavigationResponse: (controller, navigationResponse) async {
                return NavigationResponseAction.ALLOW;
              },
              onLoadStop: (controller, url) async {
                debugPrint('=======> Page onLoadStop: $url');
                getCookiesData(url!);
              },
              onProgressChanged: (InAppWebViewController controller, int progress) {
                setState(() {
                  this.progress = progress / 100;
                });
              },
              onConsoleMessage: (controller, consoleMessage) async {
                if (consoleMessage.message == 'WebSocket Open') {
                  final url = await controller.getUrl();
                  getCookiesData(url!);
                } else {
                  if (_channel != null) {
                    _channel!.sink.close();
                  }
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _requestPermissions() async {
    if (Platform.isIOS || Platform.isMacOS) {
      await flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          );
      await flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<MacOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          );
    } else if (Platform.isAndroid) {
      final AndroidFlutterLocalNotificationsPlugin? androidImplementation = flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

      final bool? grantedNotificationPermission = await androidImplementation?.requestNotificationsPermission();
      setState(() {
        notificationsEnabled = grantedNotificationPermission ?? false;
      });
    }
  }

  Future<void> _isAndroidPermissionGranted() async {
    if (Platform.isAndroid) {
      final bool granted = await flutterLocalNotificationsPlugin
              .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
              ?.areNotificationsEnabled() ??
          false;

      setState(() {
        notificationsEnabled = granted;
      });
    }
  }
}

import 'dart:convert';
import 'dart:developer';
import 'dart:io';
import 'dart:typed_data';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:tinselcrm_mobile/core/local_notification/local_notification.dart';
import 'package:tinselcrm_mobile/features/home_view/repositories/api_epository.dart';
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class WebViewTab extends StatefulWidget {
  final String? url;
  final int? windowId;
  final Function() onStateUpdated;
  final Function(CreateWindowAction createWindowAction) onCreateTabRequested;
  final Function() onCloseTabRequested;
  final Function(InAppWebViewController) onTabRefreshRequested;

  String? get currentUrl {
    final state = (key as GlobalKey).currentState as _WebViewTabState?;
    return state?._url;
  }

  bool? get isSecure {
    final state = (key as GlobalKey).currentState as _WebViewTabState?;
    return state?._isSecure;
  }

  Uint8List? get screenshot {
    final state = (key as GlobalKey).currentState as _WebViewTabState?;
    return state?._screenshot;
  }

  String? get title {
    final state = (key as GlobalKey).currentState as _WebViewTabState?;
    return state?._title;
  }

  Favicon? get favicon {
    final state = (key as GlobalKey).currentState as _WebViewTabState?;
    return state?._favicon;
  }

  const WebViewTab(
      {required GlobalKey key,
      this.url,
      required this.onStateUpdated,
      required this.onCloseTabRequested,
      required this.onCreateTabRequested,
      required this.onTabRefreshRequested,
      this.windowId})
      : assert(url != null || windowId != null),
        super(key: key);

  @override
  State<WebViewTab> createState() => _WebViewTabState();

  Future<void> updateScreenshot() async {
    final state = (key as GlobalKey).currentState as _WebViewTabState?;
    await state?.updateScreenshot();
  }

  Future<void> pause() async {
    final state = (key as GlobalKey).currentState as _WebViewTabState?;
    await state?.pause();
  }

  Future<void> resume() async {
    final state = (key as GlobalKey).currentState as _WebViewTabState?;
    await state?.resume();
  }

  Future<bool> canGoBack() async {
    final state = (key as GlobalKey).currentState as _WebViewTabState?;
    return await state?.canGoBack() ?? false;
  }

  Future<void> goBack() async {
    final state = (key as GlobalKey).currentState as _WebViewTabState?;
    await state?.goBack();
  }

  Future<bool> canGoForward() async {
    final state = (key as GlobalKey).currentState as _WebViewTabState?;
    return await state?.canGoForward() ?? false;
  }

  Future<void> goForward() async {
    final state = (key as GlobalKey).currentState as _WebViewTabState?;
    await state?.goForward();
  }
}

class _WebViewTabState extends State<WebViewTab> with WidgetsBindingObserver {
  InAppWebViewController? _webViewController;
  WebSocketChannel? _channel;
  Uint8List? _screenshot;
  String _url = '';
  bool? _isSecure;
  String _title = '';
  Favicon? _favicon;
  double _progress = 0;

  final _cookieManager = CookieManager.instance();
  bool _isConnected = false;

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
  final localNotification = NotificationPlugin();

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
        log('=====> SocketException $e');
      } on WebSocketChannelException catch (e) {
        log('=====> WebSocketChannelException $e');
      }
      _channel!.stream.listen(
        (message) {
          final notification = json.decode(message) as Map<String, dynamic>;
          localNotification.showNotification(
            title: notification['title'],
            body: notification['message'],
          );

          log('message=====> Received message: $message');
        },
        onDone: () {
          log('onDone=====> Connection Closed');
        },
        onError: (error) {
          log('onError=====> ERROR $error');
        },
      );
    } catch (e) {
      log('=====> Error connecting to WebSocket: $e');
    }
  }

  Future<void> getCookiesData(WebUri url) async {
    final cookies = await _cookieManager.getCookies(url: url);
    final sessionId = cookies.firstWhere((cookie) => cookie.name == 'sessionId').value;

    setState(() {
      if (sessionId != null && !_isConnected) {
        // Connect to WebSocket with sessionId token
        log('=======> Connecting to WebSocket...');
        connectToWebSocket(sessionId);
      }
      _isConnected = true;
      log('=======> Connected: $_isConnected');
    });
  }

  void _getLocalStorageData(String from) async {
    String script = """
      (function() {
        return JSON.stringify(localStorage);
      })();
    """;

    String result = await _webViewController!.evaluateJavascript(source: script);
    final loginData = jsonDecode(result)['login'];

    final api = ApiRepository();
    log("STORAGE $from ${jsonDecode(loginData)['id']}");
    await api.saveFCM(id: jsonDecode(loginData)['id']);
  }

  Future<void> onMessageOpenedApp(RemoteMessage message) async {
    handleNotificationTap(message);
  }

  Future<void> readFirebaseInitialLink() async {
    final message = await FirebaseMessaging.instance.getInitialMessage();
    log("readFirebaseInitialLink ${message?.data}");
    // if (message != null) {
    //   // handleNotificationTap(message);
    // }
  }

  Future<void> readFirebaseNotification() async {
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      log("readFirebaseNotification ${message.data}");
      localNotification.showNotification(
        title: message.notification?.title ?? '',
        body: message.notification?.body ?? '',
        payload: '',
      );
    });
  }

  void handleNotificationTap(RemoteMessage message) async {
    if (message.notification != null) {
      if ((message.notification?.body ?? '').toLowerCase().contains('')) {
        //routes to the page
      }
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _url = widget.url ?? '';
    localNotification.initializeNotifications();
    FirebaseMessaging.onMessageOpenedApp.listen(onMessageOpenedApp);

    WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
      readFirebaseNotification();
      readFirebaseInitialLink();
    });
  }

  @override
  void dispose() {
    _webViewController = null;
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!kIsWeb) {
      if (state == AppLifecycleState.resumed) {
        resume();
        _webViewController?.resumeTimers();
      } else {
        pause();
        _webViewController?.pauseTimers();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final url = widget.url;

    return Column(
      children: [
        Expanded(
          child: Stack(
            children: [
              Container(
                color: Colors.white,
              ),
              InAppWebView(
                windowId: widget.windowId,
                initialUrlRequest: url != null ? URLRequest(url: WebUri(url)) : null,
                initialSettings: InAppWebViewSettings(
                  javaScriptCanOpenWindowsAutomatically: true,
                  supportMultipleWindows: true,
                  isFraudulentWebsiteWarningEnabled: true,
                  safeBrowsingEnabled: true,
                  mediaPlaybackRequiresUserGesture: false,
                  allowsInlineMediaPlayback: true,
                ),
                onWebViewCreated: (controller) async {
                  _webViewController = controller;
                  widget.onTabRefreshRequested(_webViewController!);
                  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
                    await controller.startSafeBrowsing();
                  }
                  _getLocalStorageData('onWebViewCreated');
                },
                onLoadStart: (controller, url) {
                  _favicon = null;
                  _title = '';
                  if (url != null) {
                    _url = url.toString();
                    _isSecure = urlIsSecure(url);
                  }
                  widget.onStateUpdated.call();
                },
                onLoadStop: (controller, url) async {
                  updateScreenshot();

                  if (url != null) {
                    final sslCertificate = await controller.getCertificate();
                    _url = url.toString();
                    _isSecure = sslCertificate != null || urlIsSecure(url);
                  }

                  final favicons = await _webViewController?.getFavicons();
                  if (favicons != null && favicons.isNotEmpty) {
                    for (final favicon in favicons) {
                      if (_favicon == null) {
                        _favicon = favicon;
                      } else if (favicon.width != null && (favicon.width ?? 0) > (_favicon?.width ?? 0)) {
                        _favicon = favicon;
                      }
                    }
                  }
                  _getLocalStorageData('onLoadStop');
                  getCookiesData(url!);

                  widget.onStateUpdated.call();
                },
                onUpdateVisitedHistory: (controller, url, isReload) {
                  if (url != null) {
                    _url = url.toString();
                    widget.onStateUpdated.call();
                  }
                  _getLocalStorageData('onUpdateVisitedHistory');
                },
                onTitleChanged: (controller, title) {
                  _title = title ?? '';
                  widget.onStateUpdated.call();
                },
                onProgressChanged: (controller, progress) {
                  setState(() {
                    _progress = progress / 100;
                  });
                },
                onCreateWindow: (controller, createWindowAction) async {
                  widget.onCreateTabRequested(createWindowAction);
                  return true;
                },
                onCloseWindow: (controller) {
                  widget.onCloseTabRequested();
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
              _progress < 1.0
                  ? LinearProgressIndicator(
                      value: _progress,
                    )
                  : Container(),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> updateScreenshot() async {
    _screenshot = await _webViewController
        ?.takeScreenshot(
            screenshotConfiguration: ScreenshotConfiguration(compressFormat: CompressFormat.JPEG, quality: 20))
        .timeout(
          const Duration(milliseconds: 1500),
          onTimeout: () => null,
        );
  }

  Future<void> pause() async {
    if (!kIsWeb) {
      if (defaultTargetPlatform == TargetPlatform.iOS) {
        await _webViewController?.setAllMediaPlaybackSuspended(suspended: true);
      } else if (defaultTargetPlatform == TargetPlatform.android) {
        await _webViewController?.pause();
      }
    }
  }

  Future<void> resume() async {
    if (!kIsWeb) {
      if (defaultTargetPlatform == TargetPlatform.iOS) {
        await _webViewController?.setAllMediaPlaybackSuspended(suspended: false);
      } else if (defaultTargetPlatform == TargetPlatform.android) {
        await _webViewController?.resume();
      }
    }
  }

  Future<bool> canGoBack() async {
    return await _webViewController?.canGoBack() ?? false;
  }

  Future<void> goBack() async {
    if (await canGoBack()) {
      await _webViewController?.goBack();
    }
  }

  Future<bool> canGoForward() async {
    return await _webViewController?.canGoForward() ?? false;
  }

  Future<void> goForward() async {
    if (await canGoForward()) {
      await _webViewController?.goForward();
    }
  }

  static bool urlIsSecure(Uri url) {
    return (url.scheme == "https") || isLocalizedContent(url);
  }

  static bool isLocalizedContent(Uri url) {
    return (url.scheme == "file" ||
        url.scheme == "chrome" ||
        url.scheme == "data" ||
        url.scheme == "javascript" ||
        url.scheme == "about");
  }
}

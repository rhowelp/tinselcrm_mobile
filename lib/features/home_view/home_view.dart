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
        print('=====> SocketException $e');
      } on WebSocketChannelException catch (e) {
        print('=====> WebSocketChannelException $e');
      }
      _channel!.stream.listen(
        (message) {
          final notification = json.decode(message) as Map<String, dynamic>;
          localNotification.showNotification(
            title: notification['title'],
            body: notification['message'],
          );

          print('message=====> Received message: $message');
        },
        onDone: () {
          print('onDone=====> Connection Closed');
        },
        onError: (error) {
          print('onError=====> ERROR $error');
        },
      );
    } catch (e) {
      print('=====> Error connecting to WebSocket: $e');
    }
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
            // ignore: unnecessary_lambdas
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
                  print('=======> Page started loading: $url');
                });
              },
              shouldOverrideUrlLoading: (controller, navigationAction) async {
                var uri = navigationAction.request.url;
                print('URI $uri');
                return NavigationActionPolicy.ALLOW;
              },
              onUpdateVisitedHistory: (controller, url, isReload) {
                webViewController!.loadUrl(urlRequest: URLRequest(url: url));
                isReload = true;
              },
              onNavigationResponse: (controller, navigationResponse) async {
                return NavigationResponseAction.ALLOW;
              },
              onLoadStop: (controller, url) async {
                print('=======> Page onLoadStop: $url');
                final cookies = await _cookieManager.getCookies(url: url!);
                print('COOKIE ${cookies.map((e) => e.toJson()).toList()}');
                final sessionId = cookies.firstWhere((cookie) => cookie.name == 'sessionId').value;

                setState(() {
                  print('=======> Page finished loading: $url');

                  if (sessionId != null && !_isConnected) {
                    // Connect to WebSocket with sessionId token
                    print('=======> Connecting to WebSocket...');
                    connectToWebSocket(sessionId);
                  }
                  print('=======>  $_isConnected');
                });
              },
              onProgressChanged: (InAppWebViewController controller, int progress) {
                setState(() {
                  this.progress = progress / 100;
                });
              },
              onConsoleMessage: (controller, consoleMessage) {
                print('=======> CONSOLE ${consoleMessage.message}');
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

// import 'dart:convert';
// import 'dart:io';

// import 'package:flutter/material.dart';
// import 'package:flutter_inappwebview/flutter_inappwebview.dart';
// import 'package:flutter_local_notifications/flutter_local_notifications.dart';
// import 'package:tinselcrm_mobile/core/local_notification/local_notification.dart';
// import 'package:web_socket_channel/io.dart';
// import 'package:web_socket_channel/web_socket_channel.dart';
// import 'package:webview_flutter/webview_flutter.dart';

// class HomePageView extends StatefulWidget {
//   const HomePageView({super.key});

//   @override
//   State<HomePageView> createState() => _HomePageViewState();
// }

// class _HomePageViewState extends State<HomePageView> {
//   WebSocketChannel? _channel;
//   final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
//   final localNotification = NotificationPlugin();
//   late final WebViewController _controller;
//   late final PlatformWebViewControllerCreationParams params;
//   final _cookieManager = CookieManager.instance();
//   bool _isConnected = false;
//   double progress = 0;

//   Future<void> getUnionBank() async {
//     try {
//       await _controller.enableZoom(true);
//       await _controller.setJavaScriptMode(JavaScriptMode.unrestricted);
//       await _controller.setBackgroundColor(Colors.green.withOpacity(0.3));
//       await _controller.addJavaScriptChannel('Print', onMessageReceived: (logs) {
//         print('CONSOLE ${logs.message}');
//       });
//       await _controller.setOnConsoleMessage((logs) {
//         print('CONSOLE2 ${logs.message}');
//       });
//       await _controller.((logs) {
//         print('CONSOLE2 ${logs.message}');
//       });
//       await _controller.setNavigationDelegate(
//         NavigationDelegate(
//           onUrlChange: (change) {
//             print("CHANGED ${change.url}");
//             final url = Uri.parse(change.url!);
//             if (url.pathSegments.isNotEmpty) {
//               if (url.pathSegments.first == 'login') {
//                 if (_channel != null) {
//                   _channel!.sink.close();
//                   print('onDone=====> Connection Closed');
//                 }
//               }
//             }
//           },
//           onProgress: (int progress) {
//             setState(() {
//               this.progress = progress / 100;
//             });
//             print('=====================> onProgress $progress');
//           },
//           onPageStarted: (String url) {
//             print('=====================> onPageStarted');
//           },
//           onPageFinished: (String url) async {
//             final cookies = await _cookieManager.getCookies(url: WebUri(url));
//             print('COOKIE ${cookies.map((e) => e.toJson()).toList()}');
//             final sessionId = cookies.firstWhere((cookie) => cookie.name == 'sessionId').value;
//             print('sessionId $sessionId');
//             setState(() {
//               print('Page finished loading: $url');

//               if (sessionId != null && !_isConnected) {
//                 // Connect to WebSocket with sessionId token
//                 print('Connecting to WebSocket...');
//                 connectToWebSocket(sessionId);
//               }
//               print('_isConnected $_isConnected');
//             });
//           },
//           onWebResourceError: (error) {
//             debugPrint(
//               '''
//                   ERROR:
//                   code: ${error.errorCode}
//                   description ${error.description}
//                   errorType: ${error.errorType}
//                   isForMainFrame: ${error.isForMainFrame}
//                 ''',
//             );
//           },
//           onNavigationRequest: (request) {
//             if (request.url.startsWith('https://')) {
//               return NavigationDecision.navigate;
//             } else {
//               return NavigationDecision.prevent;
//             }
//           },
//         ),
//       );

//       await _controller.loadRequest(Uri.parse('https://dev2.tinselcrm.com/login'));
//       // final String cookies = await _controller.ja('document.cookie');
//     } catch (e) {
//       debugPrint('Error $e');
//       throw Exception(e);
//     }
//   }

//   void connectToWebSocket(String sessionId) async {
//     try {
//       _channel = IOWebSocketChannel.connect(
//         'wss://dev2.tinselcrm.com/webSocketServer',
//         headers: {
//           'Cookie': 'sessionId=$sessionId',
//         },
//       );
//       try {
//         await _channel!.ready;
//       } on SocketException catch (e) {
//         print('=====> SocketException $e');
//       } on WebSocketChannelException catch (e) {
//         print('=====> WebSocketChannelException $e');
//       }
//       _channel!.stream.listen(
//         (message) {
//           final notification = json.decode(message) as Map<String, dynamic>;
//           localNotification.showNotification(
//             title: notification['title'],
//             body: notification['message'],
//           );

//           print('=====> Received message: $message');
//         },
//         onDone: () {
//           print('onDone=====> Connection Closed');
//         },
//         onError: (error) {
//           print('onError=====> ERROR $error');
//         },
//       );
//     } catch (e) {
//       print('=====> Error connecting to WebSocket: $e');
//     }
//   }

//   @override
//   initState() {
//     super.initState();
//     _controller = WebViewController(); 
//     getUnionBank();
//     _requestPermissions();
//     _isAndroidPermissionGranted();
//     localNotification.initializeNotifications();
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         actions: <Widget>[
//           IconButton(
//             icon: const Icon(Icons.arrow_back),
//             onPressed: () async {
//               _controller.goBack();
//             },
//           ),
//           IconButton(
//             icon: const Icon(Icons.arrow_forward),
//             onPressed: () {
//               _controller.goForward();
//             },
//           ),
//           IconButton(
//             icon: const Icon(Icons.refresh),
//             onPressed: () {
//               _controller.reload();
//             },
//           ),
//         ],
//       ),
//       body: SafeArea(
//         child: Column(
//           children: [
//             Container(
//               child: progress < 1.0
//                   ? Padding(
//                       padding: const EdgeInsets.all(2),
//                       child: LinearProgressIndicator(value: progress),
//                     )
//                   : Container(),
//             ),
//             Expanded(child: WebViewWidget(controller: _controller)),
//           ],
//         ),
//       ),
//     );
//   }

//   bool notificationsEnabled = false;
//   Future<void> _requestPermissions() async {
//     if (Platform.isIOS || Platform.isMacOS) {
//       await flutterLocalNotificationsPlugin
//           .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
//           ?.requestPermissions(
//             alert: true,
//             badge: true,
//             sound: true,
//           );
//       await flutterLocalNotificationsPlugin
//           .resolvePlatformSpecificImplementation<MacOSFlutterLocalNotificationsPlugin>()
//           ?.requestPermissions(
//             alert: true,
//             badge: true,
//             sound: true,
//           );
//     } else if (Platform.isAndroid) {
//       final AndroidFlutterLocalNotificationsPlugin? androidImplementation = flutterLocalNotificationsPlugin
//           .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

//       final bool? grantedNotificationPermission = await androidImplementation?.requestNotificationsPermission();
//       setState(() {
//         notificationsEnabled = grantedNotificationPermission ?? false;
//       });
//     }
//   }

//   Future<void> _isAndroidPermissionGranted() async {
//     if (Platform.isAndroid) {
//       final bool granted = await flutterLocalNotificationsPlugin
//               .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
//               ?.areNotificationsEnabled() ??
//           false;

//       setState(() {
//         notificationsEnabled = granted;
//       });
//     }
//   }
// }

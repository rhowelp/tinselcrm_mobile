import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:tinselcrm_mobile/core/local_notification/local_notification.dart';
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
  final _urlController = TextEditingController();
  final _urlFocusNode = FocusNode();
  String _currentUrl = '';
  String title = '';
  double progress = 0;
  bool? isSecure;
  bool isUrlUpdating = false;
  InAppWebViewController? webViewController;
  final _cookieManager = CookieManager.instance();
  bool _isConnected = false;

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
    _currentUrl = 'https://app.tinselcrm.com/login';
    _isAndroidPermissionGranted();
    _requestPermissions();
    localNotification.initializeNotifications();
  }

  final webStorageManager = WebStorageManager.instance();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.max,
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            FutureBuilder<bool>(
              future: webViewController?.canGoBack() ?? Future.value(false),
              builder: (context, snapshot) {
                final canGoBack = snapshot.hasData ? snapshot.data! : false;
                return IconButton(
                  icon: const Icon(Icons.chevron_left),
                  onPressed: !canGoBack
                      ? null
                      : () {
                          webViewController?.goBack();
                        },
                );
              },
            ),
            FutureBuilder<bool>(
              future: webViewController?.canGoForward() ?? Future.value(false),
              builder: (context, snapshot) {
                final canGoForward = snapshot.hasData ? snapshot.data! : false;
                return IconButton(
                  icon: const Icon(Icons.chevron_right),
                  onPressed: !canGoForward
                      ? null
                      : () {
                          webViewController?.goForward();
                        },
                );
              },
            ),
            Expanded(
              child: isUrlUpdating
                  ? TextFormField(
                      controller: _urlController,
                      decoration: InputDecoration(
                        hintText: 'Enter URL',
                        isDense: true,
                        contentPadding: EdgeInsets.all(10),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(30)),
                      ),
                      focusNode: _urlFocusNode,
                      onTapOutside: (event) {
                        _urlFocusNode.unfocus();
                        setState(() {
                          isUrlUpdating = false;
                        });
                      },
                      onFieldSubmitted: (url) {
                        if (WebUri(url).isValidUri) {
                          print("SUBMITTED");
                          _urlFocusNode.unfocus();
                          setState(() {
                            isUrlUpdating = false;
                            _urlController.text = url;
                          });

                          webViewController!.loadUrl(urlRequest: URLRequest(url: WebUri(url)));
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Not a valid URL.'),
                            ),
                          );
                        }
                      },
                    )
                  : GestureDetector(
                      onLongPress: () {
                        if (kDebugMode) {
                          setState(() {
                            _urlFocusNode.requestFocus();
                            isUrlUpdating = true;
                          });
                        }
                      },
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            title,
                            overflow: TextOverflow.fade,
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.max,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              isSecure != null
                                  ? Icon(
                                      isSecure == true ? Icons.lock : Icons.lock_open,
                                      color: isSecure == true ? Colors.green : Colors.red,
                                      size: 12,
                                    )
                                  : Container(),
                              const SizedBox(
                                width: 5,
                              ),
                              Flexible(
                                child: Text(
                                  _currentUrl,
                                  style: const TextStyle(fontSize: 12, color: Colors.white70),
                                  overflow: TextOverflow.fade,
                                ),
                              ),
                            ],
                          )
                        ],
                      ),
                    ),
            ),
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () {
                webViewController?.reload();
              },
            ),
          ],
        ),
      ),
      body: Column(children: <Widget>[
        Expanded(
            child: Stack(
          children: [
            InAppWebView(
              key: webViewKey,
              initialUrlRequest: URLRequest(url: WebUri(_currentUrl)),
              initialSettings: InAppWebViewSettings(
                  transparentBackground: true, safeBrowsingEnabled: true, isFraudulentWebsiteWarningEnabled: true),
              onWebViewCreated: (controller) async {
                webViewController = controller;
                if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
                  await controller.startSafeBrowsing();
                }
              },
              onLoadStart: (controller, url) {
                if (url != null) {
                  setState(() {
                    this._currentUrl = url.toString();
                    isSecure = urlIsSecure(url);
                  });
                }
              },
              onLoadStop: (controller, url) async {
                if (url != null) {
                  setState(() {
                    this._currentUrl = url.toString();
                  });
                }

                debugPrint('=======> Page onLoadStop: $url');
                getCookiesData(url!);

                final sslCertificate = await controller.getCertificate();
                setState(() {
                  isSecure = sslCertificate != null || (urlIsSecure(url));
                });
              },
              onUpdateVisitedHistory: (controller, url, isReload) {
                if (url != null) {
                  setState(() {
                    this._currentUrl = url.toString();
                  });
                }
              },
              onTitleChanged: (controller, title) {
                if (title != null) {
                  setState(() {
                    this.title = title;
                  });
                }
              },
              onProgressChanged: (controller, progress) {
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
              shouldOverrideUrlLoading: (controller, navigationAction) async {
                final url = navigationAction.request.url;
                if (navigationAction.isForMainFrame &&
                    url != null &&
                    !['http', 'https', 'file', 'chrome', 'data', 'javascript', 'about'].contains(url.scheme)) {
                  // if (await canLaunchUrl(url)) {
                  //   launchUrl(url);
                  //   return NavigationActionPolicy.CANCEL;
                  // }
                }
                return NavigationActionPolicy.ALLOW;
              },
            ),
            progress < 1.0 ? LinearProgressIndicator(value: progress) : Container(),
          ],
        )),
      ]),
      // bottomNavigationBar: BottomAppBar(
      //   child: Row(
      //     mainAxisSize: MainAxisSize.max,
      //     mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      //     children: <Widget>[
      //       IconButton(
      //         icon: const Icon(Icons.refresh),
      //         onPressed: () {
      //           webViewController?.reload();
      //         },
      //       ),
      //       PopupMenuButton<int>(
      //         onSelected: (item) => handleClick(item),
      //         itemBuilder: (context) => [
      //           // PopupMenuItem<int>(
      //           //   enabled: false,
      //           //   child: Column(
      //           //     children: [
      //           //       Row(
      //           //         children: const [
      //           //           FlutterLogo(),
      //           //           Expanded(
      //           //             child: Center(
      //           //               child: Text(
      //           //                 'Other options',
      //           //                 style: TextStyle(color: Colors.black),
      //           //               ),
      //           //             ),
      //           //           ),
      //           //         ],
      //           //       ),
      //           //       const Divider()
      //           //     ],
      //           //   ),
      //           // ),
      //           PopupMenuItem<int>(
      //             value: 0,
      //             child: Row(
      //               children: const [
      //                 Icon(Icons.open_in_browser),
      //                 SizedBox(
      //                   width: 5,
      //                 ),
      //                 Text('Open in the Browser')
      //               ],
      //             ),
      //           ),
      //           PopupMenuItem<int>(
      //             value: 1,
      //             child: Row(
      //               children: const [
      //                 Icon(Icons.clear_all),
      //                 SizedBox(
      //                   width: 5,
      //                 ),
      //                 Text('Clear your browsing data')
      //               ],
      //             ),
      //           ),
      //         ],
      //       ),
      //     ],
      //   ),
      // ),
    );
  }

  void handleClick(int item) async {
    switch (item) {
      case 0:
        await InAppBrowser.openWithSystemBrowser(url: WebUri(_currentUrl));
        break;
      case 1:
        await InAppWebViewController.clearAllCache();
        if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
          await webViewController?.clearHistory();
        }
        setState(() {});
        break;
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

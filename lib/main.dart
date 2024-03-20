
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:tinselcrm_mobile/app/app.dart';

final userScripts = <UserScript>[];
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  runApp(const App());
}

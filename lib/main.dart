import 'package:anyinspect_server/anyinspect_server.dart';
import 'package:bot_toast/bot_toast.dart';
import 'package:flutter/material.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:window_manager/window_manager.dart';

import './includes.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await WindowManager.instance.ensureInitialized();
  await initEnv();
  WindowManager.instance.setTitle('AnyInspect');

  String? localIpAddress = await NetworkInfo().getWifiIP();
  await AnyInspectServer.instance.start(
    address: localIpAddress!,
    port: 7700,
  );

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  Widget build(BuildContext context) {
    final botToastBuilder = BotToastInit();
    return MaterialApp(
      theme: lightThemeData,
      darkTheme: darkThemeData,
      builder: (context, child) {
        child = botToastBuilder(context, child);
        return child;
      },
      navigatorObservers: [BotToastNavigatorObserver()],
      home: const HomePage(),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:planotech/network.dart';
import 'package:planotech/networkcontroll.dart';
import 'package:planotech/splash.dart';
Future<void> main() async {
  DependencyInjection.init();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.leanBack);
    Get.put(NetworkController());
    return GetMaterialApp(
      debugShowCheckedModeBanner: false,
      home: SplashScreen(),
);
}
}
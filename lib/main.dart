import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:warehouse_data_autosync/core/routes/app_pages.dart';
import 'package:warehouse_data_autosync/core/routes/app_routes.dart';
import 'package:warehouse_data_autosync/firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: 'Warehouse SQLite App',
      navigatorKey: Get.key,
      initialRoute: AppRoutes.splash,
      getPages: AppPages.routes,
      smartManagement: SmartManagement.full,
    );
  }
}

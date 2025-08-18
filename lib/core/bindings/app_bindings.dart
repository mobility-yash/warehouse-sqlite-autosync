import 'package:get/get.dart';

import '../../domain/controllers/home_controller.dart';
import '../../domain/controllers/splash_controller.dart';
import '../../domain/controllers/sync_controller.dart';

// Bindings to inject controllers/services globally with GetX
class AppBindings extends Bindings {
  @override
  void dependencies() {
    Get.put<SplashController>(SplashController());
    Get.put<SyncController>(SyncController(), permanent: true);
    Get.put<HomeController>(HomeController(), permanent: true);
  }
}

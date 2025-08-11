import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:warehouse_data_autosync/core/clients/database/database_client.dart';
import 'package:warehouse_data_autosync/core/clients/firebase/firebase_client.dart';
import 'package:warehouse_data_autosync/core/clients/internet/connectivity_client.dart';
import 'package:warehouse_data_autosync/features/dashboard/controller/dashboard_controller.dart';
import 'package:warehouse_data_autosync/features/splash/controller/splash_controller.dart';
import 'package:warehouse_data_autosync/features/sync/controller/sync_controller.dart';

class SplashBinding extends Bindings {
  @override
  void dependencies() {
    final dbClient = Get.find<DatabaseClient>();
    final sharedPrefs = Get.find<SharedPreferences>();

    Get.put(SplashController(dbClient: dbClient, prefs: sharedPrefs));
  }
}

class SyncBinding extends Bindings {
  @override
  void dependencies() {
    final dbClient = Get.find<DatabaseClient>();
    final sharedPrefs = Get.find<SharedPreferences>();
    final firebasePrefs = Get.find<FirebaseClient>();

    Get.put(
      SyncController(
        dbClient: dbClient,
        firebaseClient: firebasePrefs,
        prefs: sharedPrefs,
      ),
    );
  }
}

class DashboardBinding extends Bindings {
  @override
  void dependencies() {
    final dbClient = Get.find<DatabaseClient>();
    final sharedPrefs = Get.find<SharedPreferences>();
    final firebasePrefs = Get.find<FirebaseClient>();
    final connectivityClient = Get.find<ConnectivityClient>();

    Get.put(
      DashboardController(
        dbClient: dbClient,
        firebaseClient: firebasePrefs,
        prefs: sharedPrefs,
        connectivityClient: connectivityClient,
      ),
    );
  }
}

class NotificationListBinding extends Bindings {
  @override
  void dependencies() {}
}

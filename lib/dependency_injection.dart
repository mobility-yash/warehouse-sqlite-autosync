import 'package:get/get.dart';
import 'package:internet_connection_checker_plus/internet_connection_checker_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:warehouse_data_autosync/core/clients/database/database_client.dart';
import 'package:warehouse_data_autosync/core/clients/database/database_client_impl.dart';
import 'package:warehouse_data_autosync/core/clients/firebase/firebase_client.dart';
import 'package:warehouse_data_autosync/core/clients/firebase/firebase_client_impl.dart';
import 'package:warehouse_data_autosync/core/clients/internet/connectivity_client.dart';
import 'package:warehouse_data_autosync/core/clients/internet/connectivity_client_impl.dart';
import 'package:warehouse_data_autosync/core/clients/shared_pref/shared_pref_client.dart';
import 'package:warehouse_data_autosync/core/clients/shared_pref/shared_pref_client_impl.dart';

Future<void> initDependencies() async {
  // Firebase
  Get.put<FirebaseClient>(FirebaseClientImpl());

  // Internet
  Get.lazyPut<InternetConnection>(() => InternetConnection());
  Get.lazyPut<ConnectivityClient>(
    () => ConnectivityClientImpl(Get.find<InternetConnection>()),
  );

  // SharedPreferences
  final sharedPrefs = await SharedPreferences.getInstance();
  Get.put<SharedPreferences>(sharedPrefs);

  final sharedPrefClient = SharedPreferencesClientImpl(sharedPrefs);
  Get.put<SharedPreferencesClient>(sharedPrefClient);

  // SQLite
  Get.put<DatabaseClient>(DatabaseClientImpl());
}

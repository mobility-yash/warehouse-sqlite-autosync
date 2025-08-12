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
  Get.put<FirebaseClient>(FirebaseClientImpl(), permanent: true);

  // Internet
  Get.put<InternetConnection>(InternetConnection(), permanent: true);
  Get.put<ConnectivityClient>(
    ConnectivityClientImpl(Get.find<InternetConnection>()),
    permanent: true,
  );

  // SharedPreferences
  final sharedPrefs = await SharedPreferences.getInstance();
  Get.put<SharedPreferences>(sharedPrefs, permanent: true);

  final sharedPrefClient = SharedPreferencesClientImpl(sharedPrefs);
  Get.put<SharedPreferencesClient>(sharedPrefClient, permanent: true);

  // SQLite
  Get.put<DatabaseClient>(DatabaseClientImpl(), permanent: true);
}

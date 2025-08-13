import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:warehouse_data_autosync/core/clients/database/database_client.dart';
import 'package:warehouse_data_autosync/core/constants/constants.dart';
import 'package:warehouse_data_autosync/core/routes/app_routes.dart';

class SplashController extends GetxController {
  final DatabaseClient dbClient;
  final SharedPreferences prefs;

  SplashController({required this.dbClient, required this.prefs});

  @override
  void onInit() {
    debugPrint("Yash [SplashController] [onInit] - Controller initialized");
    super.onInit();
    _initialize();
  }

  Future<void> _initialize() async {
    debugPrint(
      "Yash [SplashController] [_initialize] - Initialization started",
    );

    final waitMinimumSplashDuration = Future.delayed(
      const Duration(seconds: 2),
    );

    final isFirstLaunch = prefs.getBool(YStrings.firstTimeLaunch) ?? true;
    debugPrint(
      "Yash [SplashController] [_initialize] - isFirstLaunch: $isFirstLaunch",
    );

    // First launch logic
    if (isFirstLaunch) {
      debugPrint(
        "Yash [SplashController] [_initialize] - First launch detected. Setting default sync states",
      );
      debugPrint(
        "Yash [SplashController] [_initialize] - Setting '${YStrings.lastInitSyncSuccess}' to false",
      );
      await prefs.setBool(YStrings.lastInitSyncSuccess, false);

      for (final table in YArrays.allTables) {
        debugPrint(
          "Yash [SplashController] [_initialize] - Setting '${YStrings.syncStatusPrefix}$table' to false",
        );
        await prefs.setBool('${YStrings.syncStatusPrefix}$table', false);
      }

      await waitMinimumSplashDuration;

      debugPrint(
        "Yash [SplashController] [_initialize] - Navigating to Sync screen for first-time sync",
      );
      Get.offAllNamed(AppRoutes.sync);
      return;
    }

    // Subsequent launches
    final lastSyncSuccess =
        prefs.getBool(YStrings.lastInitSyncSuccess) ?? false;
    debugPrint(
      "Yash [SplashController] [_initialize] - lastInitSyncSuccess: $lastSyncSuccess",
    );

    bool anyTableNeedsSync = false;
    final tableChecks = <String, bool>{};

    try {
      debugPrint(
        "Yash [SplashController] [_initialize] - Checking if tables have data in DB",
      );
      tableChecks[YStrings.locations] = await dbClient
          .isLocationsTableNotEmpty();
      tableChecks[YStrings.warehouses] = await dbClient
          .isWarehousesTableNotEmpty();
      tableChecks[YStrings.items] = await dbClient.isItemsTableNotEmpty();
      tableChecks[YStrings.notifications] = await dbClient
          .isNotificationsTableNotEmpty();
    } catch (e, stack) {
      debugPrint(
        "Yash [SplashController] [_initialize] - ERROR checking DB tables: $e",
      );
      debugPrint(stack.toString());
    }

    debugPrint(
      "Yash [SplashController] [_initialize] - Table data check results: $tableChecks",
    );

    for (final entry in tableChecks.entries) {
      final table = entry.key;
      final hasData = entry.value;

      if (!hasData) {
        debugPrint(
          "Yash [SplashController] [_initialize] - Table '$table' is empty → marking as NOT synced",
        );
        await prefs.setBool('${YStrings.syncStatusPrefix}$table', false);
        anyTableNeedsSync = true;
      } else {
        final status =
            prefs.getBool('${YStrings.syncStatusPrefix}$table') ?? false;
        debugPrint(
          "Yash [SplashController] [_initialize] - Table '$table' has data → Sync status: $status",
        );

        if (!status) {
          debugPrint(
            "Yash [SplashController] [_initialize] - '$table' marked as needing sync",
          );
          anyTableNeedsSync = true;
        }
      }
    }

    await waitMinimumSplashDuration;

    if (!lastSyncSuccess || anyTableNeedsSync) {
      debugPrint(
        "Yash [SplashController] [_initialize] - Sync required → Navigating to Sync screen lastSyncSuccess: $lastSyncSuccess, anyTableNeedsSync: $anyTableNeedsSync ",
      );
      Get.offAllNamed(AppRoutes.sync);
    } else {
      debugPrint(
        "Yash [SplashController] [_initialize] - All data synced → Navigating to Dashboard",
      );
      Get.offAllNamed(AppRoutes.dashboard);
    }
  }
}

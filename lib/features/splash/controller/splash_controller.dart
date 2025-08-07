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
    super.onInit();
    _initialize();
  }

  Future<void> _initialize() async {
    debugPrint('[SplashController] Initialization started');

    final waitMinimumSplashDuration = Future.delayed(
      const Duration(seconds: 2),
    );

    final isFirstLaunch = prefs.getBool(YStrings.firstTimeLaunch) ?? true;
    debugPrint('[SplashController] isFirstLaunch: $isFirstLaunch');

    if (isFirstLaunch) {
      debugPrint(
        '[SplashController] First launch detected. Setting defaults...',
      );
      await prefs.setBool(YStrings.firstTimeLaunch, false);
      await prefs.setBool(YStrings.lastInitSyncSuccess, false);

      for (final table in YArrays.allTables) {
        debugPrint(
          '[SplashController] Setting initial sync status for $table to false',
        );
        await prefs.setBool('${YStrings.syncStatusPrefix}$table', false);
      }

      await waitMinimumSplashDuration;

      debugPrint(
        '[SplashController] Navigating to Sync screen for first-time sync',
      );
      Get.offAllNamed(AppRoutes.sync);
      return;
    }

    final lastSyncSuccess =
        prefs.getBool(YStrings.lastInitSyncSuccess) ?? false;
    debugPrint('[SplashController] lastInitSyncSuccess: $lastSyncSuccess');

    bool anyTableNeedsSync = false;

    final tableChecks = {
      YStrings.locations: await dbClient.isLocationsTableNotEmpty(),
      YStrings.warehouses: await dbClient.isWarehousesTableNotEmpty(),
      YStrings.items: await dbClient.isItemsTableNotEmpty(),
      YStrings.notifications: await dbClient.isNotificationsTableNotEmpty(),
    };

    debugPrint('[SplashController] Table data presence check: $tableChecks');

    for (final entry in tableChecks.entries) {
      final table = entry.key;
      final hasData = entry.value;

      if (!hasData) {
        debugPrint(
          '[SplashController] Table "$table" is empty. Marking as not synced.',
        );
        await prefs.setBool('${YStrings.syncStatusPrefix}$table', false);
        await prefs.remove('${YStrings.lastSyncPrefix}$table');
        anyTableNeedsSync = true;
      } else {
        final status =
            prefs.getBool('${YStrings.syncStatusPrefix}$table') ?? false;
        debugPrint(
          '[SplashController] Table "$table" has data. Sync status: $status',
        );

        if (!status) {
          debugPrint(
            '[SplashController] Sync status for "$table" is false. Marking as needing sync.',
          );
          anyTableNeedsSync = true;
        }
      }
    }

    await waitMinimumSplashDuration;

    if (!lastSyncSuccess || anyTableNeedsSync) {
      debugPrint(
        '[SplashController] Sync required. Navigating to Sync screen.',
      );
      Get.offAllNamed(AppRoutes.sync);
    } else {
      debugPrint(
        '[SplashController] All syncs successful. Navigating to Dashboard.',
      );
      Get.offAllNamed(AppRoutes.dashboard);
    }
  }
}

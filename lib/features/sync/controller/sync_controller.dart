import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:warehouse_data_autosync/core/clients/database/database_client.dart';
import 'package:warehouse_data_autosync/core/constants/constants.dart';
import 'package:warehouse_data_autosync/core/routes/app_routes.dart';

import '../../../core/clients/firebase/firebase_client.dart';

class SyncController extends GetxController {
  final DatabaseClient dbClient;
  final FirebaseClient firebaseClient;
  final SharedPreferences prefs;

  SyncController({
    required this.dbClient,
    required this.firebaseClient,
    required this.prefs,
  });

  /// Tracks per-table syncing states
  final tableSyncing = <String, bool>{}.obs;
  final tableSynced = <String, bool>{}.obs;

  /// UI loading state
  final isLoading = false.obs;

  /// Whether this is the first launch
  late bool isFirstLaunch;

  @override
  void onInit() {
    super.onInit();
    _setupInitialState();
  }

  Future<void> _setupInitialState() async {
    final localMetadata = await dbClient.getSyncMetadataMap();
    final isMetadataEmpty = localMetadata.isEmpty;

    if (isMetadataEmpty) {
      debugPrint('[SyncController] First launch detected — metadata empty');
      for (final table in YArrays.allTables) {
        tableSyncing[table] = false;
        tableSynced[table] =
            prefs.getBool('${YStrings.syncStatusPrefix}$table') ?? false;
      }
      await _performFirstTimeSync();
    } else {
      debugPrint('[SyncController] Subsequent launch — checking metadata');
      await _checkSyncMetadataAndDecide();
    }
  }

  /// First-time sync in defined order
  Future<void> _performFirstTimeSync() async {
    isLoading.value = true;
    debugPrint('[SyncController] Performing first-time sync sequence...');

    final syncOrder = [
      YStrings.locations,
      YStrings.warehouses,
      YStrings.items,
      YStrings.notifications,
    ];

    bool allSuccess = true;

    for (final table in syncOrder) {
      final success = await _syncTable(table, isFirstTime: true);
      if (!success) {
        allSuccess = false;
        await dbClient.updateSyncMetadata(table, null);
      }
    }

    await prefs.setBool(YStrings.lastInitSyncSuccess, allSuccess);
    isLoading.value = false;

    if (allSuccess) {
      Get.offAllNamed(AppRoutes.dashboard);
    } else {
      debugPrint('[SyncController] Some tables failed during first-time sync.');
    }
  }

  /// Second time and later: use sync_metadata table for comparison
  Future<void> _checkSyncMetadataAndDecide() async {
    isLoading.value = true;

    final lastSyncSuccess =
        prefs.getBool(YStrings.lastInitSyncSuccess) ?? false;

    if (!lastSyncSuccess) {
      debugPrint(
        '[SyncController] Last initial sync failed — redoing first-time sync',
      );
      await _performFirstTimeSync();
      return;
    }

    final localMetadata = await dbClient.getSyncMetadataMap();
    final remoteMetadata = await firebaseClient.fetchSyncMetadata();

    bool anyNeedsSync = false;
    for (final table in YArrays.allTables) {
      final localUpdatedAt = localMetadata[table];
      final remoteUpdatedAt = remoteMetadata[table];

      if (remoteUpdatedAt != null &&
          (localUpdatedAt == null || remoteUpdatedAt.isAfter(localUpdatedAt))) {
        debugPrint('[SyncController] $table needs sync');
        anyNeedsSync = true;
        tableSynced[table] = false;
      }
    }

    isLoading.value = false;

    if (!anyNeedsSync) {
      Get.offAllNamed(AppRoutes.dashboard);
    }
  }

  /// Sync a single table
  Future<bool> _syncTable(String table, {bool isFirstTime = false}) async {
    tableSyncing[table] = true;

    try {
      final data = await firebaseClient.fetchTableData(table);

      if (table == YStrings.notifications) {
        final processedData = data.map((row) {
          row['synced'] = 1;
          return row;
        }).toList();
        await dbClient.insertOrUpdateTable(table, processedData);
      } else {
        await dbClient.insertOrUpdateTable(table, data);
      }

      final remoteUpdatedAt = await firebaseClient.getTableUpdatedAt(table);
      await dbClient.updateSyncMetadata(table, remoteUpdatedAt);

      prefs.setBool('${YStrings.syncStatusPrefix}$table', true);
      tableSynced[table] = true;

      tableSyncing[table] = false;
      return true;
    } catch (e, stack) {
      debugPrint('[SyncController] Error syncing $table: $e');
      debugPrint(stack.toString());

      prefs.setBool('${YStrings.syncStatusPrefix}$table', false);
      tableSynced[table] = false;
      tableSyncing[table] = false;
      return false;
    }
  }

  /// Trigger re-sync for a single table (from UI button)
  Future<void> resyncTable(String table) async {
    await _syncTable(table);
  }

  /// Retry all failed tables
  Future<void> resyncFailedTables() async {
    for (final table in YArrays.allTables) {
      if (!tableSynced[table]!) {
        await _syncTable(table);
      }
    }
  }
}

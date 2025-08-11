import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:warehouse_data_autosync/core/clients/database/database_client.dart';
import 'package:warehouse_data_autosync/core/clients/firebase/firebase_client.dart';
import 'package:warehouse_data_autosync/core/clients/internet/connectivity_client.dart';
import 'package:warehouse_data_autosync/core/constants/constants.dart';
import 'package:warehouse_data_autosync/core/routes/app_routes.dart';

class SyncController extends GetxController {
  final DatabaseClient dbClient;
  final FirebaseClient firebaseClient;
  final SharedPreferences prefs;
  final ConnectivityClient connectivityClient;

  SyncController({
    required this.dbClient,
    required this.firebaseClient,
    required this.prefs,
    required this.connectivityClient,
  });

  final tableSyncing = <String, bool>{}.obs;
  final tableSynced = <String, bool>{}.obs;
  final isLoading = false.obs;
  late bool isFirstLaunch;

  @override
  void onInit() {
    super.onInit();
    _setupInitialState();
  }

  Future<bool> _hasNetwork() async {
    try {
      final result = await InternetAddress.lookup(
        'google.com',
      ).timeout(const Duration(seconds: 5));
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  Future<void> _setupInitialState() async {
    final localMetadata = await dbClient.getSyncMetadataMap();
    isFirstLaunch = localMetadata.isEmpty;

    for (final table in YArrays.allTables) {
      tableSyncing[table] = false;
      tableSynced[table] =
          prefs.getBool('${YStrings.syncStatusPrefix}$table') ?? false;
    }

    if (isFirstLaunch) {
      debugPrint('[SyncController] First launch detected');
      await _performFirstTimeSync();
    } else {
      debugPrint('[SyncController] Subsequent launch');
      await _checkSyncMetadataAndDecide();
    }
  }

  Future<void> _performFirstTimeSync() async {
    final hasNet = await _hasNetwork();
    if (!hasNet) {
      debugPrint('[SyncController] No network on first-time sync → all fail');
      for (final table in YArrays.allTables) {
        tableSynced[table] = false;
      }
      return;
    }

    isLoading.value = true;
    debugPrint('[SyncController] Performing first-time sync...');
    bool allSuccess = true;

    for (final table in YArrays.allTables) {
      final success = await _syncTable(table, isFirstTime: true);
      if (!success) allSuccess = false;
    }

    await prefs.setBool(YStrings.lastInitSyncSuccess, allSuccess);
    isLoading.value = false;

    if (allSuccess) {
      debugPrint('[SyncController] All tables success in first-time syncing.');
    } else {
      debugPrint('[SyncController] Some tables failed during first-time sync.');
    }
  }

  Future<void> _checkSyncMetadataAndDecide() async {
    final hasNet = await _hasNetwork();
    if (!hasNet) {
      debugPrint('[SyncController] No network — marking failed as ❌ icons');
      // Keep previous tableSynced values from prefs
      return;
    }

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

    for (final table in YArrays.allTables) {
      final localTime = localMetadata[table];
      final remoteTime = remoteMetadata[table];

      bool needsSync =
          remoteTime != null &&
              (localTime == null || remoteTime.isAfter(localTime)) ||
          (localTime != null &&
              (remoteTime == null || localTime.isAfter(remoteTime)));

      if (needsSync) {
        tableSynced[table] = false;
      }
    }
    isLoading.value = false;
  }

  Future<bool> _syncTable(String table, {bool isFirstTime = false}) async {
    tableSyncing[table] = true;
    tableSynced[table] = false; // Mark as fail initially until success

    // Check network connectivity before syncing
    // final hasNetwork = await connectivityClient.getSmartStatus();
    // if (!hasNetwork) {
    //   debugPrint('[SyncController] No network - skipping sync for $table');
    //   tableSyncing[table] = false;
    //   tableSynced[table] = false; // Mark fail, no sync attempt
    //   prefs.setBool('${YStrings.syncStatusPrefix}$table', false);
    //   return false;
    // }

    try {
      final data = await firebaseClient.fetchTableData(table);
      if (table == YStrings.notifications || table == YStrings.items) {
        final processedData = data.map((row) {
          row[YStrings.colSynced] = 1;
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
      debugPrint('[SyncController] Table $table sync SUCCESS');
      return true;
    } catch (e, stack) {
      debugPrint('[SyncController] Table $table sync FAILED: $e');
      debugPrint(stack.toString());
      prefs.setBool('${YStrings.syncStatusPrefix}$table', false);
      tableSynced[table] = false;
      return false;
    } finally {
      tableSyncing[table] = false;
    }
  }

  Future<void> resyncTable(String table) async {
    await _syncTable(table);
  }

  Future<void> resyncFailedTables() async {
    for (final table in YArrays.allTables) {
      if (tableSynced[table] == false) {
        await _syncTable(table);
      }
    }
  }

  void continueToDashboard() {
    Get.offAllNamed(AppRoutes.dashboard);
  }
}

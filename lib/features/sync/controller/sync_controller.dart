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
  final tableErrors = <String, String?>{}.obs;
  final isLoading = false.obs;
  late bool isFirstLaunch;

  @override
  void onInit() {
    debugPrint('[SyncController] onInit() called');
    super.onInit();
    _setupInitialState();
  }

  Future<void> _setupInitialState() async {
    debugPrint('[SyncController] Initializing state...');

    final localMetadata = await dbClient.getSyncMetadataMap();
    final allValuesNull = localMetadata.values.every((value) => value == null);

    isFirstLaunch = localMetadata.isEmpty || allValuesNull;

    debugPrint(
      '[SyncController] isFirstLaunch = $isFirstLaunch (empty=${localMetadata.isEmpty}, allNull=$allValuesNull)',
    );

    for (final table in YArrays.allTables) {
      tableSyncing[table] = false;
      tableSynced[table] =
          prefs.getBool('${YStrings.syncStatusPrefix}$table') ?? false;
      tableErrors[table] = null;
    }

    if (isFirstLaunch) {
      debugPrint('[SyncController] First launch detected → first-time sync');
      await _performFirstTimeSync();
    } else {
      debugPrint('[SyncController] Subsequent launch → checking metadata');
      await _checkSyncMetadataAndDecide();
    }
  }

  Future<void> _performFirstTimeSync() async {
    debugPrint('[SyncController] Performing first-time sync...');
    final hasNet = await connectivityClient.getSmartStatus();
    debugPrint('[SyncController] Network check (first-time sync): $hasNet');

    if (!hasNet) {
      debugPrint('[SyncController] No internet → all tables fail ❌');
      for (final table in YArrays.allTables) {
        tableSynced[table] = false;
        tableErrors[table] = 'No internet connection';
      }
      return;
    }

    isLoading.value = true;
    bool allSuccess = true;

    for (final table in YArrays.allTables) {
      final success = await _syncTable(table, isFirstTime: true);
      if (!success) allSuccess = false;
    }

    await prefs.setBool(YStrings.lastInitSyncSuccess, allSuccess);
    isLoading.value = false;
  }

  Future<void> _checkSyncMetadataAndDecide() async {
    debugPrint('[SyncController] Checking metadata for changes...');
    final hasNet = await connectivityClient.getSmartStatus();
    debugPrint('[SyncController] Network check (metadata compare): $hasNet');

    if (!hasNet) {
      debugPrint(
        '[SyncController] No network — leaving previous states and errors',
      );
      return;
    }

    isLoading.value = true;
    final lastSyncSuccess =
        prefs.getBool(YStrings.lastInitSyncSuccess) ?? false;
    if (!lastSyncSuccess) {
      debugPrint(
        '[SyncController] Last initial sync failed → running first-time sync again',
      );
      await _performFirstTimeSync();
      return;
    }

    final localMetadata = await dbClient.getSyncMetadataMap();
    final remoteMetadata = await firebaseClient.fetchSyncMetadata();

    for (final table in YArrays.allTables) {
      final localTime = localMetadata[table];
      final remoteTime = remoteMetadata[table];

      final needsSync =
          (remoteTime != null &&
              (localTime == null || remoteTime.isAfter(localTime))) ||
          (localTime != null &&
              (remoteTime == null || localTime.isAfter(remoteTime)));

      if (needsSync) {
        debugPrint(
          '[SyncController] Table $table needs sync → marking ❌ and queuing',
        );
        tableSynced[table] = false;
        tableErrors[table] = 'Outdated or missing data';
      } else {
        debugPrint('[SyncController] Table $table already up-to-date ✅');
        tableErrors[table] = null;
      }
    }
    isLoading.value = false;
  }

  Future<bool> _syncTable(String table, {bool isFirstTime = false}) async {
    debugPrint('[SyncController] ===== SYNC START for: $table =====');
    tableSyncing[table] = true;
    tableSynced[table] = false;
    tableErrors[table] = null;

    final hasNetwork = await connectivityClient.getSmartStatus();
    debugPrint('[SyncController] Network check for $table: $hasNetwork');
    if (!hasNetwork) {
      debugPrint('[SyncController] No network — fail $table ❌');
      tableSyncing[table] = false;
      tableSynced[table] = false;
      tableErrors[table] = 'No internet connection';
      prefs.setBool('${YStrings.syncStatusPrefix}$table', false);
      return false;
    }

    try {
      debugPrint('[SyncController] Fetching data from Firebase: $table');
      final data = await firebaseClient.fetchTableData(table);
      debugPrint('[SyncController] $table fetched ${data.length} rows');

      if (table == YStrings.notifications || table == YStrings.items) {
        debugPrint('[SyncController] Setting colSynced=1 for all rows: $table');
        final processedData = data.map((row) {
          row[YStrings.colSynced] = 1;
          return row;
        }).toList();
        await dbClient.insertOrUpdateTable(table, processedData);
      } else {
        await dbClient.insertOrUpdateTable(table, data);
      }
      debugPrint('[SyncController] $table updated in local DB');

      DateTime? remoteUpdatedAt;
      try {
        remoteUpdatedAt = await firebaseClient.getTableUpdatedAt(table);
      } catch (e) {
        debugPrint('[SyncController] getTableUpdatedAt($table) error: $e');
      }

      await dbClient.updateSyncMetadata(table, remoteUpdatedAt);
      debugPrint(
        '[SyncController] $table sync metadata updated → $remoteUpdatedAt',
      );

      if (remoteUpdatedAt == null) {
        debugPrint('[SyncController] No updatedAt received → fail $table ❌');
        tableSynced[table] = false;
        tableErrors[table] = 'Failed to retrieve update timestamp';
        prefs.setBool('${YStrings.syncStatusPrefix}$table', false);
        return false;
      }

      prefs.setBool('${YStrings.syncStatusPrefix}$table', true);
      tableSynced[table] = true;
      tableErrors[table] = null;
      debugPrint('[SyncController] Table $table sync SUCCESS ✅');
      return true;
    } catch (e, stack) {
      debugPrint('[SyncController] Table $table sync FAILED ❌ → $e');
      debugPrint(stack.toString());
      tableSynced[table] = false;
      tableErrors[table] = e.toString();
      prefs.setBool('${YStrings.syncStatusPrefix}$table', false);
      return false;
    } finally {
      tableSyncing[table] = false;
      debugPrint('[SyncController] ===== SYNC END for: $table =====');
    }
  }

  Future<void> resyncTable(String table) async {
    debugPrint('[SyncController] Manual resync → $table');
    await _syncTable(table);
  }

  Future<void> resyncFailedTables() async {
    debugPrint('[SyncController] Resync ALL failed tables');
    for (final table in YArrays.allTables) {
      if (tableSynced[table] == false) {
        await _syncTable(table);
      }
    }
  }

  void continueToDashboard() {
    debugPrint('[SyncController] Navigating to dashboard');
    Get.offAllNamed(AppRoutes.dashboard);
  }
}

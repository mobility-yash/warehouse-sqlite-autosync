import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:warehouse_data_autosync/core/clients/database/database_client.dart';
import 'package:warehouse_data_autosync/core/clients/firebase/firebase_client.dart';
import 'package:warehouse_data_autosync/core/clients/internet/connectivity_client.dart';
import 'package:warehouse_data_autosync/core/common/models/sync_metadata_model.dart';
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
  final RxBool _showGlobalResyncButton = false.obs;
  bool get showGlobalResyncButton => _showGlobalResyncButton.value;

  late bool isFirstLaunch;

  // Helper to mark all tables with network error
  void _markAllTablesNetworkError() {
    const errorMsg =
        'No internet connection. Please reconnect and press "Resync" to complete syncing.';
    for (final table in YArrays.allTables) {
      tableSyncing[table] = false;
      tableSynced[table] = false;
      tableErrors[table] = errorMsg;
      prefs.setBool('${YStrings.syncStatusPrefix}$table', false);
    }
    _showGlobalResyncButton.value = true;
    debugPrint(
      "Yash [SyncController] [NetworkCheck] - Internet unavailable. All tables marked as failed. Ask user to reconnect and hit global Resync.",
    );
  }

  @override
  void onInit() async {
    debugPrint("Yash [SyncController] [onInit] - Controller initialized");

    final hasNetwork = await connectivityClient.getSmartStatus();
    if (!hasNetwork) {
      debugPrint(
        "Yash [SyncController] [onInit] - No internet at start. Skipping sync init.",
      );
      _markAllTablesNetworkError();
      return;
    }

    super.onInit();
    _setupInitialState();
  }

  Future<void> _setupInitialState() async {
    debugPrint(
      "Yash [SyncController] [_setupInitialState] - Setting up initial state",
    );

    final hasNet = await connectivityClient.getSmartStatus();
    if (!hasNet) {
      debugPrint(
        "Yash [SyncController] [_setupInitialState] - No internet at sync setup start",
      );
      _markAllTablesNetworkError();
      return;
    }

    await dbClient.getAllSyncMetadata();
    isFirstLaunch = prefs.getBool(YStrings.firstTimeLaunch) ?? true;
    debugPrint(
      "Yash [SyncController] [_setupInitialState] - Is first launch: $isFirstLaunch",
    );

    for (final table in YArrays.allTables) {
      tableSyncing[table] = false;
      tableSynced[table] =
          prefs.getBool('${YStrings.syncStatusPrefix}$table') ?? false;
      tableErrors[table] = null;
    }

    if (isFirstLaunch) {
      debugPrint(
        "Yash [SyncController] [_setupInitialState] - Performing first-time sync",
      );
      await _performFirstTimeSync();
    } else {
      debugPrint(
        "Yash [SyncController] [_setupInitialState] - Checking and syncing bidirectional",
      );
      await _checkAndSyncBidirectional();
    }
  }

  Future<void> _performFirstTimeSync() async {
    final hasNet = await connectivityClient.getSmartStatus();
    if (!hasNet) {
      debugPrint(
        "Yash [SyncController] [_performFirstTimeSync] - No internet at first sync start",
      );
      _markAllTablesNetworkError();
      return;
    }

    debugPrint(
      "Yash [SyncController] [_performFirstTimeSync] - Setting '${YStrings.firstTimeLaunch}' to false",
    );
    await prefs.setBool(YStrings.firstTimeLaunch, false);

    isLoading.value = true;
    for (final table in YArrays.allTables) {
      debugPrint(
        "Yash [SyncController] [_performFirstTimeSync] - Syncing table: $table",
      );
      await _syncTableBidirectional(table, isFirstTime: true);
    }
    isLoading.value = false;
    debugPrint(
      "Yash [SyncController] [_performFirstTimeSync] - First-time sync complete",
    );
  }

  Future<void> _checkAndSyncBidirectional() async {
    final hasNet = await connectivityClient.getSmartStatus();
    if (!hasNet) {
      debugPrint(
        "Yash [SyncController] [_checkAndSyncBidirectional] - No internet",
      );
      _markAllTablesNetworkError();
      return;
    }

    debugPrint(
      "Yash [SyncController] [_checkAndSyncBidirectional] - Checking tables for sync",
    );

    isLoading.value = true;
    final localMetaMap = await dbClient.getAllSyncMetadata();
    final remoteMetaMap = await firebaseClient.fetchSyncMetadata();

    for (final table in YArrays.allTables) {
      final localMeta = localMetaMap[table];
      final remoteTime = remoteMetaMap[table];
      bool needsSync = false;

      if (localMeta != null) {
        final localOnly =
            localMeta.lastLocalUpdatedAt != null &&
            (localMeta.lastRemoteUpdatedAt == null ||
                DateTime.parse(localMeta.lastLocalUpdatedAt!).isAfter(
                  DateTime.parse(
                    localMeta.lastRemoteUpdatedAt ?? '1970-01-01T00:00:00Z',
                  ),
                ));
        final remoteOnly =
            remoteTime != null &&
            (localMeta.lastRemoteUpdatedAt == null ||
                remoteTime.isAfter(
                  DateTime.parse(
                    localMeta.lastRemoteUpdatedAt ?? '1970-01-01T00:00:00Z',
                  ),
                ));

        needsSync = localOnly || remoteOnly;
      } else {
        needsSync = true;
      }

      debugPrint(
        "Yash [SyncController] [_checkAndSyncBidirectional] - Table: $table, Needs Sync: $needsSync",
      );

      if (needsSync) {
        await _syncTableBidirectional(table);
      }
    }

    isLoading.value = false;
    debugPrint(
      "Yash [SyncController] [_checkAndSyncBidirectional] - Sync check complete",
    );
  }

  Future<void> _syncTableBidirectional(
    String table, {
    bool isFirstTime = false,
  }) async {
    debugPrint(
      "Yash [SyncController] [_syncTableBidirectional] - Starting sync for table: $table, FirstTime: $isFirstTime",
    );

    final hasNetwork = await connectivityClient.getSmartStatus();
    if (!hasNetwork) {
      debugPrint(
        "Yash [SyncController] [_syncTableBidirectional] - No internet for table: $table",
      );
      tableSyncing[table] = false;
      tableSynced[table] = false;
      tableErrors[table] =
          'No internet connection. Please reconnect and press "Resync" to complete syncing.';
      prefs.setBool('${YStrings.syncStatusPrefix}$table', false);
      return;
    }

    tableSyncing[table] = true;
    tableSynced[table] = false;
    tableErrors[table] = null;

    try {
      final localMeta =
          await dbClient.getSyncMetadata(table) ?? SyncMetadataModel.empty();
      debugPrint(
        "Yash [SyncController] [_syncTableBidirectional] - DB.getSyncMetadata($table) → ${localMeta.toString()}",
      );

      final remoteMetaMap = await firebaseClient.fetchSyncMetadata();
      final remoteTime = remoteMetaMap[table];
      debugPrint(
        "Yash [SyncController] [_syncTableBidirectional] - remoteTime for table '$table' → $remoteTime",
      );

      final localLastLocal = localMeta.lastLocalUpdatedAt != null
          ? DateTime.parse(localMeta.lastLocalUpdatedAt!)
          : null;
      final localLastRemote = localMeta.lastRemoteUpdatedAt != null
          ? DateTime.parse(localMeta.lastRemoteUpdatedAt!)
          : null;

      final hasLocalChanges =
          localLastLocal != null &&
          (localLastRemote == null || localLastLocal.isAfter(localLastRemote));
      final hasRemoteChanges =
          remoteTime != null &&
          (localLastRemote == null || remoteTime.isAfter(localLastRemote));

      debugPrint(
        "Yash [SyncController] [_syncTableBidirectional] - hasLocalChanges: $hasLocalChanges, hasRemoteChanges: $hasRemoteChanges",
      );

      if (hasRemoteChanges) {
        final remoteData = await firebaseClient.fetchTableData(
          table,
          updatedAfter: localLastRemote,
        );
        debugPrint(
          "Yash [SyncController] [_syncTableBidirectional] - Firebase.fetchTableData($table) → ${remoteData.length} records",
        );

        await dbClient.insertOrUpdateTable(table, remoteData);
        await dbClient.updateLastRemoteUpdatedAt(
          entity: table,
          lastRemoteUpdatedAt: remoteTime!.toIso8601String(),
        );
      }

      if (hasLocalChanges) {
        if (table == YStrings.items) {
          final unsynced = await dbClient.getUnsyncedItems();
          debugPrint(
            "Yash [SyncController] [_syncTableBidirectional] - DB.getUnsyncedItems() → ${unsynced.length} items",
          );
          for (final item in unsynced) {
            await firebaseClient.saveItem(item);
          }
          await dbClient.markItemsAsSynced(unsynced.map((e) => e.id).toList());
        } else if (table == YStrings.notifications) {
          final unsynced = await dbClient.getUnsyncedNotifications();
          debugPrint(
            "Yash [SyncController] [_syncTableBidirectional] - DB.getUnsyncedNotifications() → ${unsynced.length} notifications",
          );
          for (final notif in unsynced) {
            await firebaseClient.saveNotification(notif);
          }
          await dbClient.markNotificationsAsSynced(
            unsynced.map((e) => e.id).toList(),
          );
        }
        await dbClient.updateLastLocalUpdatedAt(
          entity: table,
          lastLocalUpdatedAt: DateTime.now().toIso8601String(),
        );
      }

      final finalTimestamp =
          [
            if (localLastLocal != null) localLastLocal,
            if (remoteTime != null) remoteTime,
          ].fold<DateTime>(
            DateTime.fromMillisecondsSinceEpoch(0),
            (prev, curr) => curr.isAfter(prev) ? curr : prev,
          );
      await dbClient.updateBothLocalAndRemoteTimestamps(
        entity: table,
        updatedAt: finalTimestamp.toIso8601String(),
      );
      await firebaseClient.updateSyncMetadata(
        entity: table,
        lastTableUpdatedAt: finalTimestamp,
      );

      prefs.setBool('${YStrings.syncStatusPrefix}$table', true);
      tableSynced[table] = true;
      tableErrors[table] = null;
    } catch (e, st) {
      tableSynced[table] = false;
      tableErrors[table] = e.toString();
      prefs.setBool('${YStrings.syncStatusPrefix}$table', false);
      debugPrint("Yash [SyncController] [_syncTableBidirectional] - Error: $e");
      debugPrint(st.toString());
    } finally {
      tableSyncing[table] = false;
      _updateCanContinue();
    }
  }

  void _updateCanContinue() {
    final allTrue = YArrays.allTables.every(
      (table) => tableSynced[table] == true,
    );
    if (allTrue) {
      prefs.setBool(YStrings.lastInitSyncSuccess, true);
    }
    debugPrint(
      "Yash [SyncController] [_updateCanContinue] - All tables synced: $allTrue",
    );
  }

  Future<void> resyncTable(String table) async {
    debugPrint("Yash [SyncController] [resyncTable] - Resyncing table: $table");
    final hasNet = await connectivityClient.getSmartStatus();
    if (!hasNet) {
      debugPrint(
        "Yash [SyncController] [resyncTable] - No internet - cannot resync $table",
      );
      _markAllTablesNetworkError();
      return;
    }
    await _syncTableBidirectional(table);
  }

  Future<void> resyncFailedTables() async {
    debugPrint(
      "Yash [SyncController] [resyncFailedTables] - Attempting to resync failed tables",
    );
    final hasNet = await connectivityClient.getSmartStatus();
    if (!hasNet) {
      debugPrint(
        "Yash [SyncController] [resyncFailedTables] - No internet - cannot resync",
      );
      _markAllTablesNetworkError();
      return;
    }
    for (final table in YArrays.allTables) {
      if (tableSynced[table] == false) {
        await _syncTableBidirectional(table);
      }
    }
  }

  void continueToDashboard() {
    debugPrint(
      "Yash [SyncController] [continueToDashboard] - Navigating to dashboard",
    );
    Get.offAllNamed(AppRoutes.dashboard);
  }
}

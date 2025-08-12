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
  late bool isFirstLaunch;

  @override
  void onInit() {
    super.onInit();
    _setupInitialState();
  }

  Future<void> _setupInitialState() async {
    final localMetadata = await dbClient.getAllSyncMetadata();
    isFirstLaunch = localMetadata.isEmpty;
    for (final table in YArrays.allTables) {
      tableSyncing[table] = false;
      tableSynced[table] =
          prefs.getBool('${YStrings.syncStatusPrefix}$table') ?? false;
      tableErrors[table] = null;
    }
    if (isFirstLaunch) {
      await _performFirstTimeSync();
    } else {
      await _checkAndSyncBidirectional();
    }
  }

  Future<void> _performFirstTimeSync() async {
    final hasNet = await connectivityClient.getSmartStatus();
    if (!hasNet) {
      for (final table in YArrays.allTables) {
        tableSynced[table] = false;
        tableErrors[table] = 'No internet connection';
      }
      return;
    }
    isLoading.value = true;
    for (final table in YArrays.allTables) {
      await _syncTableBidirectional(table, isFirstTime: true);
    }
    isLoading.value = false;
  }

  Future<void> _checkAndSyncBidirectional() async {
    final hasNet = await connectivityClient.getSmartStatus();
    if (!hasNet) return;

    isLoading.value = true;
    // Local has 2 timestamps, Firebase has 1 timestamp per table
    final localMetaMap = await dbClient.getAllSyncMetadata();
    final remoteMetaMap = await firebaseClient.fetchSyncMetadata();

    for (final table in YArrays.allTables) {
      final localMeta = localMetaMap[table];
      final remoteTime = remoteMetaMap[table];
      bool needsSync = false;

      if (localMeta != null) {
        // Local changes awaiting push
        final localOnly =
            localMeta.lastLocalUpdatedAt != null &&
            (localMeta.lastRemoteUpdatedAt == null ||
                DateTime.parse(localMeta.lastLocalUpdatedAt!).isAfter(
                  DateTime.parse(
                    localMeta.lastRemoteUpdatedAt ?? '1970-01-01T00:00:00Z',
                  ),
                ));
        // Remote changes awaiting pull
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

      if (needsSync) {
        await _syncTableBidirectional(table);
      }
    }

    isLoading.value = false;
  }

  Future<void> _syncTableBidirectional(
    String table, {
    bool isFirstTime = false,
  }) async {
    tableSyncing[table] = true;
    tableSynced[table] = false;
    tableErrors[table] = null;

    final hasNetwork = await connectivityClient.getSmartStatus();
    if (!hasNetwork) {
      tableSyncing[table] = false;
      tableSynced[table] = false;
      tableErrors[table] = 'No internet connection';
      prefs.setBool('${YStrings.syncStatusPrefix}$table', false);
      return;
    }

    try {
      final localMeta =
          await dbClient.getSyncMetadata(table) ?? SyncMetadataModel.empty();
      final remoteMetaMap = await firebaseClient.fetchSyncMetadata();
      final remoteTime = remoteMetaMap[table];

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

      if (hasRemoteChanges) {
        final remoteData = await firebaseClient.fetchTableData(
          table,
          updatedAfter: localLastRemote,
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
          for (final item in unsynced) {
            await firebaseClient.saveItem(item);
          }
          await dbClient.markItemsAsSynced(unsynced.map((e) => e.id).toList());
        } else if (table == YStrings.notifications) {
          final unsynced = await dbClient.getUnsyncedNotifications();
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
      debugPrint(st.toString());
    } finally {
      tableSyncing[table] = false;
    }
  }

  Future<void> resyncTable(String table) async {
    await _syncTableBidirectional(table);
  }

  Future<void> resyncFailedTables() async {
    for (final table in YArrays.allTables) {
      if (tableSynced[table] == false) {
        await _syncTableBidirectional(table);
      }
    }
  }

  void continueToDashboard() {
    Get.offAllNamed(AppRoutes.dashboard);
  }
}

import 'package:get/get.dart';

import '../../core/services/db_helper.dart';

class SplashController extends GetxController {
  var isLoading = true.obs;

  @override
  void onInit() {
    super.onInit();
    _initApp();
  }

  Future<void> _initApp() async {
    final db = await DBHelper.initDB();

    // check last sync info
    final lastSyncInfo = await db.query(
      'sync_info',
      orderBy: "id DESC",
      limit: 1,
    );

    if (lastSyncInfo.isEmpty) {
      // First run → go to SyncScreen
      Get.offAllNamed('/sync');
    } else {
      final lastSync = DateTime.tryParse(
        lastSyncInfo.first['lastSyncTime'] as String,
      );
      final status = lastSyncInfo.first['lastSyncStatus'] as String;

      if (lastSync == null) {
        Get.offAllNamed('/sync');
      } else {
        final now = DateTime.now();
        final difference = now.difference(lastSync);

        if (difference.inMinutes > 20) {
          // Older than 20 min → sync
          Get.offAllNamed('/sync');
        } else {
          if (status == "success") {
            // within 20 min and last sync ok → go home
            Get.offAllNamed('/home');
          } else {
            // last sync failed → go sync
            Get.offAllNamed('/sync');
          }
        }
      }
    }

    isLoading.value = false;
  }
}

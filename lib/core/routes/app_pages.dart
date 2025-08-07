import 'package:get/get.dart';
import 'package:warehouse_data_autosync/core/routes/app_bindings.dart';
import 'package:warehouse_data_autosync/features/dashboard/views/notification_list.dart';
import 'package:warehouse_data_autosync/features/notification_list/views/dashboard_view.dart';
import 'package:warehouse_data_autosync/features/splash/view/splash_view.dart';
import 'package:warehouse_data_autosync/features/sync/view/sync_view.dart';

import 'app_routes.dart';

class AppPages {
  static final routes = <GetPage>[
    GetPage(
      name: AppRoutes.splash,
      page: () => SplashView(),
      binding: SplashBinding(),
    ),
    GetPage(
      name: AppRoutes.sync,
      page: () => SyncView(),
      binding: SyncBinding(),
    ),
    GetPage(
      name: AppRoutes.dashboard,
      page: () => DashboardView(),
      binding: DashboardBinding(),
    ),
    // GetPage(
    //   name: AppRoutes.dummyDataUploader,
    //   page: () => DummyDataUploaderView(),
    //   binding: DashboardBinding(),
    // ),
    GetPage(
      name: AppRoutes.notificationList,
      page: () => NotificationListView(),
      binding: NotificationListBinding(),
    ),
  ];
}

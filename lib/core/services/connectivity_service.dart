import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:get/get.dart';

class ConnectivityService extends GetxService {
  final isOnline = false.obs;

  Future<ConnectivityService> init() async {
    final List<ConnectivityResult> results = await Connectivity()
        .checkConnectivity();

    isOnline.value = _mapResult(results);

    Connectivity().onConnectivityChanged.listen((
      List<ConnectivityResult> results,
    ) {
      isOnline.value = _mapResult(results);
    });

    return this;
  }

  bool _mapResult(List<ConnectivityResult> results) {
    return results.any(
      (result) =>
          result == ConnectivityResult.mobile ||
          result == ConnectivityResult.wifi,
    );
  }
}

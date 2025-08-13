import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:internet_connection_checker_plus/internet_connection_checker_plus.dart';

import 'connectivity_client.dart';

class ConnectivityClientImpl implements ConnectivityClient {
  final InternetConnection _internetConnection;

  ConnectivityClientImpl(this._internetConnection);

  StreamSubscription<bool>? _subscription;
  final StreamController<bool> _controller = StreamController<bool>.broadcast();

  bool _currentStatus = false;

  @override
  void start() {
    debugPrint(
      "Yash [ConnectivityClientImpl] [start] - Starting connectivity listener",
    );
    if (_subscription != null) {
      debugPrint(
        "Yash [ConnectivityClientImpl] [start] - Already listening, skipping",
      );
      return;
    }

    _subscription = _internetConnection.onStatusChange
        .map((status) => status == InternetStatus.connected)
        .listen((status) {
          _currentStatus = status;
          debugPrint(
            "Yash [ConnectivityClientImpl] [start] - Connectivity changed → $status",
          );
          _controller.add(status);
        });

    debugPrint("Yash [ConnectivityClientImpl] [start] - Listener started");
  }

  @override
  void stop() {
    debugPrint(
      "Yash [ConnectivityClientImpl] [stop] - Stopping connectivity listener",
    );
    _subscription?.cancel();
    _subscription = null;
    debugPrint("Yash [ConnectivityClientImpl] [stop] - Listener stopped");
  }

  @override
  bool get isListening {
    final listening = _subscription != null;
    debugPrint("Yash [ConnectivityClientImpl] [isListening] - $listening");
    return listening;
  }

  @override
  bool get currentStatus {
    debugPrint(
      "Yash [ConnectivityClientImpl] [currentStatus] - $_currentStatus",
    );
    return _currentStatus;
  }

  @override
  Stream<bool> get onConnectivityChanged {
    debugPrint(
      "Yash [ConnectivityClientImpl] [onConnectivityChanged] - Subscribed to connectivity stream",
    );
    return _controller.stream;
  }

  @override
  Future<bool> checkOnce() async {
    debugPrint(
      "Yash [ConnectivityClientImpl] [checkOnce] - Performing one-time internet connection check",
    );
    final result = await _internetConnection.hasInternetAccess;
    debugPrint("Yash [ConnectivityClientImpl] [checkOnce] - Result: $result");
    return result;
  }

  @override
  Future<bool> getSmartStatus() async {
    debugPrint(
      "Yash [ConnectivityClientImpl] [getSmartStatus] - Getting smart status",
    );
    if (isListening) {
      debugPrint(
        "Yash [ConnectivityClientImpl] [getSmartStatus] - Using current status: $_currentStatus",
      );
      return _currentStatus;
    }
    final result = await checkOnce();
    debugPrint(
      "Yash [ConnectivityClientImpl] [getSmartStatus] - One-time check result: $result",
    );
    return result;
  }
}

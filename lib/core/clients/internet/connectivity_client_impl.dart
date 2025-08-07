import 'dart:async';

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
    if (_subscription != null) return;

    _subscription = _internetConnection.onStatusChange
        .map((status) => status == InternetStatus.connected)
        .listen((status) {
          _currentStatus = status;
          _controller.add(status);
        });
  }

  @override
  void stop() {
    _subscription?.cancel();
    _subscription = null;
  }

  @override
  bool get isListening => _subscription != null;

  @override
  bool get currentStatus => _currentStatus;

  @override
  Stream<bool> get onConnectivityChanged => _controller.stream;

  @override
  Future<bool> checkOnce() => _internetConnection.hasInternetAccess;

  @override
  Future<bool> getSmartStatus() async {
    if (isListening) {
      return _currentStatus;
    }
    return await checkOnce();
  }
}

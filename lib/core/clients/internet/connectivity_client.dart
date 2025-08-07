abstract class ConnectivityClient {
  /// Starts monitoring internet connection changes.
  void start();

  /// Stops monitoring.
  void stop();

  /// Whether the stream is currently active.
  bool get isListening;

  /// Last known connectivity status.
  bool get currentStatus;

  /// Stream of connection changes (can be listened to multiple times).
  Stream<bool> get onConnectivityChanged;

  /// Performs a one-time internet connectivity check.
  Future<bool> checkOnce();

  /// Smart status: if stream is active, returns last known;
  /// otherwise, performs a one-time check.
  Future<bool> getSmartStatus();
}

abstract class SharedPreferencesClient {
  // Setters
  Future<void> setString(String key, String value);
  Future<void> setBool(String key, bool value);
  Future<void> setInt(String key, int value);
  Future<void> setDouble(String key, double value);

  // Getters
  String? getString(String key);
  bool? getBool(String key);
  int? getInt(String key);
  double? getDouble(String key);

  // Utility
  bool contains(String key);
  Future<void> remove(String key);
  Future<void> clear();
}

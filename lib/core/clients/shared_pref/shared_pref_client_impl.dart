import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'shared_pref_client.dart';

class SharedPreferencesClientImpl implements SharedPreferencesClient {
  final SharedPreferences _prefs;

  SharedPreferencesClientImpl(this._prefs);

  @override
  Future<void> setString(String key, String value) async {
    debugPrint(
      "Yash [SharedPreferencesClientImpl] [setString] - key: $key, value: $value",
    );
    await _prefs.setString(key, value);
    debugPrint(
      "Yash [SharedPreferencesClientImpl] [setString] - Saved successfully",
    );
  }

  @override
  Future<void> setBool(String key, bool value) async {
    debugPrint(
      "Yash [SharedPreferencesClientImpl] [setBool] - key: $key, value: $value",
    );
    await _prefs.setBool(key, value);
    debugPrint(
      "Yash [SharedPreferencesClientImpl] [setBool] - Saved successfully",
    );
  }

  @override
  Future<void> setInt(String key, int value) async {
    debugPrint(
      "Yash [SharedPreferencesClientImpl] [setInt] - key: $key, value: $value",
    );
    await _prefs.setInt(key, value);
    debugPrint(
      "Yash [SharedPreferencesClientImpl] [setInt] - Saved successfully",
    );
  }

  @override
  Future<void> setDouble(String key, double value) async {
    debugPrint(
      "Yash [SharedPreferencesClientImpl] [setDouble] - key: $key, value: $value",
    );
    await _prefs.setDouble(key, value);
    debugPrint(
      "Yash [SharedPreferencesClientImpl] [setDouble] - Saved successfully",
    );
  }

  @override
  String? getString(String key) {
    final value = _prefs.getString(key);
    debugPrint(
      "Yash [SharedPreferencesClientImpl] [getString] - key: $key, value: $value",
    );
    return value;
  }

  @override
  bool? getBool(String key) {
    final value = _prefs.getBool(key);
    debugPrint(
      "Yash [SharedPreferencesClientImpl] [getBool] - key: $key, value: $value",
    );
    return value;
  }

  @override
  int? getInt(String key) {
    final value = _prefs.getInt(key);
    debugPrint(
      "Yash [SharedPreferencesClientImpl] [getInt] - key: $key, value: $value",
    );
    return value;
  }

  @override
  double? getDouble(String key) {
    final value = _prefs.getDouble(key);
    debugPrint(
      "Yash [SharedPreferencesClientImpl] [getDouble] - key: $key, value: $value",
    );
    return value;
  }

  @override
  bool contains(String key) {
    final result = _prefs.containsKey(key);
    debugPrint(
      "Yash [SharedPreferencesClientImpl] [contains] - key: $key, contains: $result",
    );
    return result;
  }

  @override
  Future<void> remove(String key) async {
    debugPrint(
      "Yash [SharedPreferencesClientImpl] [remove] - Removing key: $key",
    );
    await _prefs.remove(key);
    debugPrint("Yash [SharedPreferencesClientImpl] [remove] - Key removed");
  }

  @override
  Future<void> clear() async {
    debugPrint(
      "Yash [SharedPreferencesClientImpl] [clear] - Clearing all keys",
    );
    await _prefs.clear();
    debugPrint("Yash [SharedPreferencesClientImpl] [clear] - All keys cleared");
  }
}

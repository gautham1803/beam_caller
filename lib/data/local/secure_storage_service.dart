import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../utils/constants.dart';

/// Service for secure local storage of device identity.
class SecureStorageService {
  final FlutterSecureStorage _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  static const String _favoritesKey = 'favorite_numbers';

  /// Get stored device ID.
  Future<String?> getDeviceId() async {
    return await _storage.read(key: AppConstants.storageKeyDeviceId);
  }

  /// Save device ID.
  Future<void> saveDeviceId(String deviceId) async {
    await _storage.write(key: AppConstants.storageKeyDeviceId, value: deviceId);
  }

  /// Get stored assigned number.
  Future<String?> getAssignedNumber() async {
    return await _storage.read(key: AppConstants.storageKeyNumber);
  }

  /// Save assigned number.
  Future<void> saveAssignedNumber(String number) async {
    await _storage.write(key: AppConstants.storageKeyNumber, value: number);
  }

  /// Get stored favorite numbers.
  Future<List<String>> getFavorites() async {
    final raw = await _storage.read(key: _favoritesKey);
    if (raw == null) return [];
    try {
      final list = jsonDecode(raw) as List;
      return list.cast<String>();
    } catch (_) {
      return [];
    }
  }

  /// Save favorite numbers.
  Future<void> saveFavorites(List<String> favorites) async {
    await _storage.write(key: _favoritesKey, value: jsonEncode(favorites));
  }

  /// Check if user is already registered.
  Future<bool> isRegistered() async {
    final number = await getAssignedNumber();
    return number != null && number.isNotEmpty;
  }

  /// Clear all stored data.
  Future<void> clearAll() async {
    await _storage.deleteAll();
  }
}

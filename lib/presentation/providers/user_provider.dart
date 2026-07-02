import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../data/local/secure_storage_service.dart';
import '../../data/remote/api_service.dart';
import '../../domain/models/user_model.dart';

/// State for user registration and identity.
class UserState {
  final UserModel? user;
  final bool isLoading;
  final String? error;

  const UserState({this.user, this.isLoading = false, this.error});

  UserState copyWith({UserModel? user, bool? isLoading, String? error}) {
    return UserState(
      user: user ?? this.user,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

/// Provider for user state management.
class UserNotifier extends StateNotifier<UserState> {
  final SecureStorageService _storage;
  final ApiService _apiService;

  UserNotifier(this._storage, this._apiService) : super(const UserState());

  /// Initialize: check local storage for existing number.
  Future<bool> initialize() async {
    state = state.copyWith(isLoading: true);

    try {
      final existingNumber = await _storage.getAssignedNumber();
      final existingDeviceId = await _storage.getDeviceId();

      if (existingNumber != null && existingDeviceId != null) {
        state = state.copyWith(
          user: UserModel(
            number: existingNumber,
            deviceId: existingDeviceId,
            isOnline: true,
          ),
          isLoading: false,
        );
        return true;
      }

      // Need to register
      return await _register();
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  /// Register with the backend.
  Future<bool> _register() async {
    try {
      // Generate or retrieve device ID
      String? deviceId = await _storage.getDeviceId();
      if (deviceId == null) {
        deviceId = const Uuid().v4();
        await _storage.saveDeviceId(deviceId);
      }

      // Call backend
      final result = await _apiService.register(deviceId);

      if (result['success'] == true) {
        final number = result['number'] as String;
        await _storage.saveAssignedNumber(number);

        state = state.copyWith(
          user: UserModel(
            number: number,
            deviceId: deviceId,
            isOnline: true,
          ),
          isLoading: false,
        );
        return true;
      }

      state = state.copyWith(
        isLoading: false,
        error: 'Registration failed',
      );
      return false;
    } catch (e) {
      debugPrint('Registration error: $e');
      state = state.copyWith(isLoading: false, error: 'Server unavailable');
      return false;
    }
  }

  /// Get the user's assigned number.
  String? get number => state.user?.number;

  /// Clear all stored credentials and reset.
  Future<void> resetApp() async {
    await _storage.saveAssignedNumber('');
    await _storage.saveDeviceId('');
    const fStorage = FlutterSecureStorage();
    await fStorage.deleteAll();
    state = const UserState();
  }
}

// Providers
final secureStorageProvider = Provider((ref) => SecureStorageService());
final apiServiceProvider = Provider((ref) => ApiService());

final userProvider = StateNotifierProvider<UserNotifier, UserState>((ref) {
  return UserNotifier(
    ref.read(secureStorageProvider),
    ref.read(apiServiceProvider),
  );
});

final themeModeProvider = StateProvider<ThemeMode>((ref) => ThemeMode.system);

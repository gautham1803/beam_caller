import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/local/secure_storage_service.dart';
import 'user_provider.dart';

/// Notifier to manage user's favorite numbers locally.
class FavoritesNotifier extends StateNotifier<List<String>> {
  final SecureStorageService _storage;

  FavoritesNotifier(this._storage) : super([]) {
    loadFavorites();
  }

  /// Load favorites from secure storage.
  Future<void> loadFavorites() async {
    final list = await _storage.getFavorites();
    state = list;
  }

  /// Toggle favorite status of a number.
  Future<void> toggleFavorite(String number) async {
    final cleanNum = number.replaceAll(' ', '').trim();
    if (cleanNum.length != 6) return;

    final list = List<String>.from(state);
    if (list.contains(cleanNum)) {
      list.remove(cleanNum);
    } else {
      list.add(cleanNum);
    }

    state = list;
    await _storage.saveFavorites(list);
  }

  /// Check if a number is favorited.
  bool isFavorite(String number) {
    final cleanNum = number.replaceAll(' ', '').trim();
    return state.contains(cleanNum);
  }
}

final favoritesProvider =
    StateNotifierProvider<FavoritesNotifier, List<String>>((ref) {
  return FavoritesNotifier(ref.read(secureStorageProvider));
});

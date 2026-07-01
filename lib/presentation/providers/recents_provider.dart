import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/remote/api_service.dart';
import '../../domain/models/recent_call.dart';
import 'user_provider.dart';

class RecentsState {
  final List<RecentCall> calls;
  final bool isLoading;
  final String? error;

  const RecentsState({
    this.calls = const [],
    this.isLoading = false,
    this.error,
  });

  RecentsState copyWith({
    List<RecentCall>? calls,
    bool? isLoading,
    String? error,
  }) {
    return RecentsState(
      calls: calls ?? this.calls,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class RecentsNotifier extends StateNotifier<RecentsState> {
  final ApiService _apiService;
  final Ref _ref;

  RecentsNotifier(this._apiService, this._ref) : super(const RecentsState());

  /// Fetch call history from backend.
  Future<void> fetchRecents() async {
    final myNumber = _ref.read(userProvider).user?.number;
    if (myNumber == null) return;

    state = state.copyWith(isLoading: true);

    try {
      final list = await _apiService.getRecentCalls(myNumber);
      final calls = list
          .map((item) => RecentCall.fromJson(Map<String, dynamic>.from(item)))
          .toList();

      state = state.copyWith(calls: calls, isLoading: false);
    } catch (e) {
      debugPrint('Error fetching recent calls: $e');
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to load call history',
      );
    }
  }
}

final recentsProvider =
    StateNotifierProvider<RecentsNotifier, RecentsState>((ref) {
  return RecentsNotifier(ref.read(apiServiceProvider), ref);
});

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:m3uxtream_player/app/providers/core_providers.dart';
import 'package:m3uxtream_player/core/repository/app_state_repository.dart';
import 'package:m3uxtream_player/shared/theme/appearance_preferences.dart';

class AppearanceController extends StateNotifier<AppearancePreferences> {
  AppearanceController(this._repository)
    : super(AppearancePreferences.defaults);

  final AppStateRepository _repository;

  Future<void> load() async {
    try {
      final values = await Future.wait<double>([
        _repository.getAppearanceAccentHue(
          defaultHue: AppearancePreferences.defaultAccentHue,
        ),
        _repository.getAppearanceSurfaceTone(
          defaultTone: AppearancePreferences.defaultSurfaceTone,
        ),
      ]);
      if (!mounted) return;
      state = AppearancePreferences(
        accentHue: values[0],
        surfaceTone: values[1],
      );
    } catch (_) {
      // The repository already redacts/logs the storage failure. Keeping the
      // tested defaults lets the shell render even when storage is unavailable.
    }
  }

  Future<void> setAccentHue(double hue) async {
    final previous = state;
    final next = state.copyWith(accentHue: hue);
    state = next;
    try {
      await _repository.setAppearanceAccentHue(next.accentHue);
    } catch (_) {
      if (mounted) state = previous;
    }
  }

  Future<void> setSurfaceTone(double tone) async {
    final previous = state;
    final next = state.copyWith(surfaceTone: tone);
    state = next;
    try {
      await _repository.setAppearanceSurfaceTone(next.surfaceTone);
    } catch (_) {
      if (mounted) state = previous;
    }
  }

  Future<void> reset() async {
    final previous = state;
    state = AppearancePreferences.defaults;
    try {
      await Future.wait([
        _repository.setAppearanceAccentHue(
          AppearancePreferences.defaultAccentHue,
        ),
        _repository.setAppearanceSurfaceTone(
          AppearancePreferences.defaultSurfaceTone,
        ),
      ]);
    } catch (_) {
      if (mounted) state = previous;
    }
  }
}

final appearancePreferencesProvider =
    StateNotifierProvider<AppearanceController, AppearancePreferences>((ref) {
      final controller = AppearanceController(
        ref.watch(appStateRepositoryProvider),
      );
      unawaited(controller.load());
      return controller;
    });

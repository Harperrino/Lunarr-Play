import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:m3uxtream_player/app/providers/core_providers.dart';
import 'package:m3uxtream_player/core/services/live_composition_geometry.dart';

const categoryPaneDefaultWidth = 232.0;
const categoryPaneMinimumWidth = 200.0;
const categoryPaneMaximumWidth = 420.0;

/// Persisted desktop category-pane width. Collapse state remains transient;
/// expanding the pane reapplies this width.
final categoryPaneWidthProvider =
    AsyncNotifierProvider<CategoryPaneWidthNotifier, double>(
      CategoryPaneWidthNotifier.new,
    );

class CategoryPaneWidthNotifier extends AsyncNotifier<double> {
  @override
  Future<double> build() {
    return ref
        .read(appStateRepositoryProvider)
        .getCategoryPaneWidth(defaultWidth: categoryPaneDefaultWidth);
  }

  Future<void> setWidth(double width) async {
    final bounded = width
        .clamp(categoryPaneMinimumWidth, categoryPaneMaximumWidth)
        .toDouble();
    state = AsyncData(bounded);
    try {
      await ref.read(appStateRepositoryProvider).setCategoryPaneWidth(bounded);
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
      rethrow;
    }
  }

  Future<void> reset() => setWidth(categoryPaneDefaultWidth);
}

/// Computes the largest category width that leaves the channel panel and
/// player their minimum usable widths in the current Live composition.
double dynamicCategoryPaneMaximum({
  required double contentWidth,
  required double channelWidth,
}) {
  final reservedChannelWidth = math.max(
    LiveCompositionMetrics.minimumChannelPanelOuterWidth,
    channelWidth,
  );
  final available =
      contentWidth -
      (LiveCompositionMetrics.panelGap * 2) -
      reservedChannelWidth -
      LiveCompositionMetrics.minimumPlayerWidth;
  return math.max(0, math.min(categoryPaneMaximumWidth, available));
}

double clampCategoryPaneWidth({
  required double requestedWidth,
  required double contentWidth,
  required double channelWidth,
}) {
  final maximum = dynamicCategoryPaneMaximum(
    contentWidth: contentWidth,
    channelWidth: channelWidth,
  );
  if (maximum < categoryPaneMinimumWidth) {
    return maximum;
  }
  return requestedWidth.clamp(categoryPaneMinimumWidth, maximum).toDouble();
}

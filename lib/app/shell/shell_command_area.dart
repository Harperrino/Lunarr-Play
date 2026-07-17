import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:m3uxtream_player/app/shell/shell_layout.dart';
import 'package:m3uxtream_player/core/services/live_layout_geometry.dart';
import 'package:m3uxtream_player/features/search/widgets/global_search_field.dart';
import 'package:m3uxtream_player/shared/theme/app_spacing.dart';

/// Presentation-only command area for standard shell screens.
class ShellCommandArea extends StatelessWidget {
  const ShellCommandArea({
    super.key,
    required this.title,
    this.count,
    this.supportingText,
    this.search,
    this.source,
    this.actions,
    this.leadingOpticalInset = 0,
  });

  static const titleKey = ValueKey('shell-command-area-title');
  static const countKey = ValueKey('shell-command-area-count');
  static const supportingTextKey = ValueKey(
    'shell-command-area-supporting-text',
  );
  static const searchKey = ValueKey('shell-command-area-search');
  static const sourceKey = ValueKey('shell-command-area-source');
  static const actionsKey = ValueKey('shell-command-area-actions');
  static const _countSlotHeight = 24.0;
  static const _minimumInlineSideCorridor = 180.0;

  final String title;
  final String? count;
  final String? supportingText;
  final Widget? search;
  final Widget? source;
  final Widget? actions;

  /// Restores the title/action baseline when a parent lifts only the search
  /// field optically. Standard shell command areas keep the default of zero.
  final double leadingOpticalInset;

  @override
  Widget build(BuildContext context) {
    final spacing =
        Theme.of(context).extension<AppSpacing>() ?? AppSpacing.standard;

    return LayoutBuilder(
      builder: (context, constraints) {
        final widthClass = shellWidthClassFor(constraints.maxWidth);
        final slots = _slots();
        final titleBlock = _TitleBlock(
          title: title,
          count: count,
          supportingText: supportingText,
          supportingTextMaxLines: 2,
        );
        final trailingSlots = _trailingSlots();

        if (constraints.hasBoundedWidth &&
            widthClass != ShellWidthClass.compact &&
            _hasInlineSearchCorridor(
              widthClass: widthClass,
              availableWidth: constraints.maxWidth,
              hasSearch: search != null,
              trailingSlotCount: trailingSlots.length,
              spacing: spacing.md,
            )) {
          final scale = MediaQuery.textScalerOf(context).scale(1).clamp(1, 2);
          final searchWidth = _searchWidthFor(widthClass, constraints.maxWidth);
          final scaleAwareHeight = scale > 1.0
              ? LiveLayoutMetrics.headerCommandAreaScaledHeight * scale
              : LiveLayoutMetrics.headerCommandAreaHeight;
          final commandAreaHeight =
              scaleAwareHeight +
              (count == null ? 0.0 : _countSlotHeight * scale);
          final inlineTitleBlock = _TitleBlock(
            title: title,
            count: count,
            supportingText: supportingText,
            supportingTextMaxLines: 1,
          );

          return SizedBox(
            height: commandAreaHeight,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                if (search == null)
                  Align(
                    alignment: Alignment.topLeft,
                    child: Padding(
                      padding: EdgeInsets.only(top: leadingOpticalInset),
                      child: inlineTitleBlock,
                    ),
                  )
                else
                  Positioned(
                    left: 0,
                    top: leadingOpticalInset,
                    width: math.max(
                      0,
                      (constraints.maxWidth - searchWidth) / 2 - spacing.md,
                    ),
                    child: inlineTitleBlock,
                  ),
                if (trailingSlots.isNotEmpty)
                  Positioned(
                    left: search == null
                        ? 0
                        : (constraints.maxWidth + searchWidth) / 2 + spacing.md,
                    right: 0,
                    top: leadingOpticalInset,
                    child: Align(
                      alignment: Alignment.topRight,
                      child: Wrap(
                        alignment: WrapAlignment.end,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: spacing.md,
                        runSpacing: spacing.sm,
                        children: trailingSlots,
                      ),
                    ),
                  ),
                if (search != null)
                  Positioned(
                    top: (scaleAwareHeight - GlobalSearchField.fieldHeight) / 2,
                    left: (constraints.maxWidth - searchWidth) / 2,
                    width: searchWidth,
                    child: SizedBox(
                      key: searchKey,
                      width: searchWidth,
                      child: search,
                    ),
                  ),
              ],
            ),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (leadingOpticalInset == 0)
              titleBlock
            else
              Padding(
                padding: EdgeInsets.only(top: leadingOpticalInset),
                child: titleBlock,
              ),
            for (final slot in slots) ...[
              SizedBox(height: LiveLayoutMetrics.headerTitleSearchGap),
              SizedBox(width: double.infinity, child: slot),
            ],
          ],
        );
      },
    );
  }

  static double _searchWidthFor(
    ShellWidthClass widthClass,
    double availableWidth,
  ) => switch (widthClass) {
    ShellWidthClass.wide => 720,
    ShellWidthClass.expanded =>
      (availableWidth * 0.52).clamp(600.0, 720.0).toDouble(),
    ShellWidthClass.medium =>
      (availableWidth * 0.60).clamp(520.0, 680.0).toDouble(),
    ShellWidthClass.compact => availableWidth,
  };

  static bool _hasInlineSearchCorridor({
    required ShellWidthClass widthClass,
    required double availableWidth,
    required bool hasSearch,
    required int trailingSlotCount,
    required double spacing,
  }) {
    if (!hasSearch || trailingSlotCount == 0) return true;
    final searchWidth = _searchWidthFor(widthClass, availableWidth);
    final sideCorridor = ((availableWidth - searchWidth) / 2 - spacing).clamp(
      0.0,
      double.infinity,
    );
    return sideCorridor >= _minimumInlineSideCorridor;
  }

  List<Widget> _slots() => [
    if (source != null) KeyedSubtree(key: sourceKey, child: source!),
    if (search != null) KeyedSubtree(key: searchKey, child: search!),
    if (actions != null) KeyedSubtree(key: actionsKey, child: actions!),
  ];

  List<Widget> _trailingSlots() => [
    if (source != null) KeyedSubtree(key: sourceKey, child: source!),
    if (actions != null) KeyedSubtree(key: actionsKey, child: actions!),
  ];
}

class _TitleBlock extends StatelessWidget {
  const _TitleBlock({
    required this.title,
    required this.count,
    required this.supportingText,
    required this.supportingTextMaxLines,
  });

  final String title;
  final String? count;
  final String? supportingText;
  final int supportingTextMaxLines;

  @override
  Widget build(BuildContext context) {
    final spacing =
        Theme.of(context).extension<AppSpacing>() ?? AppSpacing.standard;
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Semantics(
          header: true,
          child: Text(
            title,
            key: ShellCommandArea.titleKey,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: textTheme.titleLarge,
          ),
        ),
        if (count != null) ...[
          SizedBox(height: spacing.xs),
          Text(
            count!,
            key: ShellCommandArea.countKey,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: textTheme.labelLarge,
          ),
        ],
        if (supportingText != null) ...[
          SizedBox(height: spacing.xs),
          Text(
            supportingText!,
            key: ShellCommandArea.supportingTextKey,
            maxLines: supportingTextMaxLines,
            overflow: TextOverflow.ellipsis,
            style: textTheme.bodyMedium,
          ),
        ],
      ],
    );
  }
}

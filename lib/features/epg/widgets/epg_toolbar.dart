import 'dart:math' as math;

import 'package:flutter/material.dart';

enum EpgToolbarAction {
  now,
  backTwoHours,
  forwardTwoHours,
  backOneDay,
  forwardOneDay,
  zoomOut,
  zoomIn,
  resetZoom,
}

/// Pure responsive policy for the provider-free EPG toolbar.
class EpgToolbarLayoutPolicy {
  const EpgToolbarLayoutPolicy._();

  static const minimumInlineWidthAtDefaultScale = 600.0;

  static bool usesStackedLayout({
    required double availableWidth,
    required double textScaleFactor,
  }) {
    final effectiveScale = math.max(1.0, textScaleFactor);
    return availableWidth < minimumInlineWidthAtDefaultScale * effectiveScale;
  }
}

/// Provider-free toolbar. The screen adapter owns all EPG state and effects.
class EpgToolbar extends StatelessWidget {
  const EpgToolbar({
    super.key,
    required this.isBusy,
    required this.isEntriesLoading,
    required this.onJumpToNow,
    required this.onBackTwoHours,
    required this.onForwardTwoHours,
    required this.onBackOneDay,
    required this.onForwardOneDay,
    required this.onZoomOut,
    required this.onZoomIn,
    required this.onResetZoom,
  });

  static const inlineKey = ValueKey<String>('epg-toolbar-inline');
  static const stackedKey = ValueKey<String>('epg-toolbar-stacked');

  static ValueKey<String> actionKey(EpgToolbarAction action) =>
      ValueKey<String>('epg-toolbar-action-${action.name}');

  final bool isBusy;
  final bool isEntriesLoading;
  final VoidCallback onJumpToNow;
  final VoidCallback onBackTwoHours;
  final VoidCallback onForwardTwoHours;
  final VoidCallback onBackOneDay;
  final VoidCallback onForwardOneDay;
  final VoidCallback onZoomOut;
  final VoidCallback onZoomIn;
  final VoidCallback onResetZoom;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final stacked = EpgToolbarLayoutPolicy.usesStackedLayout(
          availableWidth: constraints.maxWidth,
          textScaleFactor: MediaQuery.textScalerOf(context).scale(1),
        );
        final title = _EpgToolbarTitle(isEntriesLoading: isEntriesLoading);
        final actions = _EpgToolbarActions(
          isBusy: isBusy,
          onJumpToNow: onJumpToNow,
          onBackTwoHours: onBackTwoHours,
          onForwardTwoHours: onForwardTwoHours,
          onBackOneDay: onBackOneDay,
          onForwardOneDay: onForwardOneDay,
          onZoomOut: onZoomOut,
          onZoomIn: onZoomIn,
          onResetZoom: onResetZoom,
        );

        if (stacked) {
          return Column(
            key: stackedKey,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [title, const SizedBox(height: 12), actions],
          );
        }

        return Row(
          key: inlineKey,
          children: [
            Expanded(child: title),
            const SizedBox(width: 16),
            actions,
          ],
        );
      },
    );
  }
}

class _EpgToolbarTitle extends StatelessWidget {
  const _EpgToolbarTitle({required this.isEntriesLoading});

  final bool isEntriesLoading;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Wrap(
      spacing: 10,
      runSpacing: 6,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Icon(
          Icons.calendar_month_rounded,
          size: 20,
          color: colorScheme.secondary,
        ),
        Text(
          'TV PROGRAMME',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 14),
        ),
        if (isEntriesLoading)
          SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
      ],
    );
  }
}

class _EpgToolbarActions extends StatelessWidget {
  const _EpgToolbarActions({
    required this.isBusy,
    required this.onJumpToNow,
    required this.onBackTwoHours,
    required this.onForwardTwoHours,
    required this.onBackOneDay,
    required this.onForwardOneDay,
    required this.onZoomOut,
    required this.onZoomIn,
    required this.onResetZoom,
  });

  final bool isBusy;
  final VoidCallback onJumpToNow;
  final VoidCallback onBackTwoHours;
  final VoidCallback onForwardTwoHours;
  final VoidCallback onBackOneDay;
  final VoidCallback onForwardOneDay;
  final VoidCallback onZoomOut;
  final VoidCallback onZoomIn;
  final VoidCallback onResetZoom;

  VoidCallback? _whenEnabled(VoidCallback callback) => isBusy ? null : callback;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        _EpgActionGroup(
          children: [
            _EpgToolbarButton(
              action: EpgToolbarAction.now,
              label: 'Jetzt',
              tooltip: 'Zum aktuellen Zeitpunkt',
              icon: Icons.my_location_rounded,
              onPressed: _whenEnabled(onJumpToNow),
            ),
            _EpgToolbarButton(
              action: EpgToolbarAction.backTwoHours,
              label: '-2h',
              tooltip: 'Zwei Stunden zurück',
              onPressed: _whenEnabled(onBackTwoHours),
            ),
            _EpgToolbarButton(
              action: EpgToolbarAction.forwardTwoHours,
              label: '+2h',
              tooltip: 'Zwei Stunden vor',
              onPressed: _whenEnabled(onForwardTwoHours),
            ),
            _EpgToolbarButton(
              action: EpgToolbarAction.backOneDay,
              label: '-1d',
              tooltip: 'Einen Tag zurück',
              onPressed: _whenEnabled(onBackOneDay),
            ),
            _EpgToolbarButton(
              action: EpgToolbarAction.forwardOneDay,
              label: '+1d',
              tooltip: 'Einen Tag vor',
              onPressed: _whenEnabled(onForwardOneDay),
            ),
          ],
        ),
        _EpgActionGroup(
          children: [
            _EpgToolbarButton(
              action: EpgToolbarAction.zoomOut,
              label: '−',
              tooltip: 'Zeitachse verkleinern',
              onPressed: _whenEnabled(onZoomOut),
            ),
            _EpgToolbarButton(
              action: EpgToolbarAction.zoomIn,
              label: '+',
              tooltip: 'Zeitachse vergrößern',
              onPressed: _whenEnabled(onZoomIn),
            ),
            _EpgToolbarButton(
              action: EpgToolbarAction.resetZoom,
              label: '100%',
              tooltip: 'Zeitachse auf 100 Prozent zurücksetzen',
              onPressed: _whenEnabled(onResetZoom),
            ),
          ],
        ),
      ],
    );
  }
}

class _EpgActionGroup extends StatelessWidget {
  const _EpgActionGroup({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: children,
    );
  }
}

class _EpgToolbarButton extends StatelessWidget {
  const _EpgToolbarButton({
    required this.action,
    required this.label,
    required this.tooltip,
    required this.onPressed,
    this.icon,
  });

  final EpgToolbarAction action;
  final String label;
  final String tooltip;
  final VoidCallback? onPressed;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final buttonStyle = TextButton.styleFrom(
      foregroundColor: colorScheme.onSurfaceVariant,
      backgroundColor: colorScheme.surfaceContainerHigh,
      disabledForegroundColor: colorScheme.onSurface.withValues(alpha: 0.38),
      disabledBackgroundColor: colorScheme.surfaceContainerLow,
      minimumSize: const Size(0, 32),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    );
    final content = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[Icon(icon, size: 12), const SizedBox(width: 4)],
        Text(
          label,
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
        ),
      ],
    );

    return Semantics(
      button: true,
      label: tooltip,
      enabled: onPressed != null,
      onTap: onPressed,
      excludeSemantics: true,
      child: Tooltip(
        message: tooltip,
        excludeFromSemantics: true,
        child: TextButton(
          key: EpgToolbar.actionKey(action),
          onPressed: onPressed,
          style: buttonStyle,
          child: content,
        ),
      ),
    );
  }
}

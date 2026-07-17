import 'dart:ui' show SemanticsAction;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:m3uxtream_player/features/epg/widgets/epg_compact_agenda.dart';
import 'package:m3uxtream_player/features/epg/widgets/epg_screen_layout.dart';
import 'package:m3uxtream_player/features/epg/widgets/epg_toolbar.dart';
import 'package:m3uxtream_player/shared/theme/app_theme.dart';

void main() {
  const actions = EpgToolbarAction.values;

  for (final width in [719.0, 720.0, 1199.0, 1200.0]) {
    testWidgets('lays out every action at ${width.toInt()}px and 200%', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await _pumpToolbar(tester, width: width, textScaleFactor: 2);

      expect(
        find.byKey(width < 1200 ? EpgToolbar.stackedKey : EpgToolbar.inlineKey),
        findsOneWidget,
      );
      for (final action in actions) {
        expect(find.byKey(EpgToolbar.actionKey(action)), findsOneWidget);
      }
      for (final label in _semanticLabels) {
        expect(find.bySemanticsLabel(label), findsOneWidget);
        expect(find.byTooltip(label), findsOneWidget);
      }
      expect(tester.takeException(), isNull);
      semantics.dispose();
    });
  }

  testWidgets('keeps the standard wide toolbar inline at 100%', (tester) async {
    await _pumpToolbar(tester, width: 1200, textScaleFactor: 1);

    expect(find.byKey(EpgToolbar.inlineKey), findsOneWidget);
    expect(find.byKey(EpgToolbar.stackedKey), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('routes all eight actions to their unchanged callbacks', (
    tester,
  ) async {
    final invoked = <EpgToolbarAction>[];
    await _pumpToolbar(
      tester,
      width: 719,
      textScaleFactor: 2,
      callbacks: _ToolbarCallbacks.recording(invoked),
    );

    for (final action in actions) {
      await tester.tap(find.byKey(EpgToolbar.actionKey(action)));
      await tester.pump();
    }

    expect(invoked, actions);
  });

  testWidgets('busy state disables every action', (tester) async {
    final invoked = <EpgToolbarAction>[];
    await _pumpToolbar(
      tester,
      width: 719,
      textScaleFactor: 2,
      isBusy: true,
      callbacks: _ToolbarCallbacks.recording(invoked),
    );

    for (final action in actions) {
      final button = find.byKey(EpgToolbar.actionKey(action));
      expect(tester.widget<TextButton>(button).onPressed, isNull);
    }
    expect(invoked, isEmpty);
  });

  testWidgets('semantics tap invokes enabled action and is absent when busy', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    final invoked = <EpgToolbarAction>[];
    await _pumpToolbar(
      tester,
      width: 719,
      callbacks: _ToolbarCallbacks.recording(invoked),
    );

    final enabledFinder = find.semantics.byLabel('Zum aktuellen Zeitpunkt');
    final enabledNode = enabledFinder.evaluate().single;
    expect(
      enabledNode.getSemanticsData().hasAction(SemanticsAction.tap),
      isTrue,
    );
    tester.semantics.tap(enabledFinder);
    await tester.pump();
    expect(invoked, [EpgToolbarAction.now]);

    await _pumpToolbar(
      tester,
      width: 719,
      isBusy: true,
      callbacks: _ToolbarCallbacks.recording(invoked),
    );
    final disabledNode = find.semantics
        .byLabel('Zum aktuellen Zeitpunkt')
        .evaluate()
        .single;
    expect(
      disabledNode.getSemanticsData().hasAction(SemanticsAction.tap),
      isFalse,
    );
    semantics.dispose();
  });

  testWidgets('actions remain keyboard focusable and activatable', (
    tester,
  ) async {
    final invoked = <EpgToolbarAction>[];
    await _pumpToolbar(
      tester,
      width: 1200,
      callbacks: _ToolbarCallbacks.recording(invoked),
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();

    expect(invoked, [EpgToolbarAction.now]);
  });

  for (final width in [719.0, 720.0]) {
    testWidgets(
      'screen composition keeps the ${width < 720 ? 'compact' : 'desktop'} '
      'body at ${width.toInt()}px and 200%',
      (tester) async {
        await _pumpScreenLayout(
          tester,
          width: width,
          height: 320,
          textScaleFactor: 2,
        );

        expect(
          find.byKey(ValueKey(width < 720 ? 'compact-body' : 'desktop-body')),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('short screen scrolls the toolbar and preserves body space', (
    tester,
  ) async {
    await _pumpScreenLayout(
      tester,
      width: 719,
      height: 180,
      textScaleFactor: 2,
    );

    final scroll = find.byKey(const ValueKey('epg-toolbar-vertical-scroll'));
    expect(tester.getSize(scroll).height, 68);
    expect(
      tester.getSize(find.byKey(const ValueKey('compact-body'))).height,
      96,
    );
    expect(tester.takeException(), isNull);
  });

  group('EpgToolbarLayoutPolicy', () {
    test('uses the scaled 1200px boundary deterministically', () {
      expect(
        EpgToolbarLayoutPolicy.usesStackedLayout(
          availableWidth: 1199,
          textScaleFactor: 2,
        ),
        isTrue,
      );
      expect(
        EpgToolbarLayoutPolicy.usesStackedLayout(
          availableWidth: 1200,
          textScaleFactor: 2,
        ),
        isFalse,
      );
    });

    test('short-height metrics reserve named toolbar and body minima', () {
      final metrics = EpgScreenVerticalMetrics.resolve(180);

      expect(metrics.gap, EpgScreenVerticalMetrics.standardGap);
      expect(metrics.maximumToolbarHeight, 68);
    });
  });
}

const _semanticLabels = [
  'Zum aktuellen Zeitpunkt',
  'Zwei Stunden zurück',
  'Zwei Stunden vor',
  'Einen Tag zurück',
  'Einen Tag vor',
  'Zeitachse verkleinern',
  'Zeitachse vergrößern',
  'Zeitachse auf 100 Prozent zurücksetzen',
];

Future<void> _pumpToolbar(
  WidgetTester tester, {
  required double width,
  double textScaleFactor = 1,
  bool isBusy = false,
  _ToolbarCallbacks callbacks = const _ToolbarCallbacks(),
}) {
  _setViewSize(tester, Size(width, 600));
  return tester.pumpWidget(
    _host(
      width: width,
      height: 240,
      textScaleFactor: textScaleFactor,
      child: EpgToolbar(
        isBusy: isBusy,
        isEntriesLoading: true,
        onJumpToNow: callbacks.onJumpToNow,
        onBackTwoHours: callbacks.onBackTwoHours,
        onForwardTwoHours: callbacks.onForwardTwoHours,
        onBackOneDay: callbacks.onBackOneDay,
        onForwardOneDay: callbacks.onForwardOneDay,
        onZoomOut: callbacks.onZoomOut,
        onZoomIn: callbacks.onZoomIn,
        onResetZoom: callbacks.onResetZoom,
      ),
    ),
  );
}

Future<void> _pumpScreenLayout(
  WidgetTester tester, {
  required double width,
  required double height,
  required double textScaleFactor,
}) {
  _setViewSize(tester, Size(width, height));
  return tester.pumpWidget(
    _host(
      width: width,
      height: height,
      textScaleFactor: textScaleFactor,
      child: EpgScreenLayout(
        toolbar: EpgToolbar(
          isBusy: false,
          isEntriesLoading: false,
          onJumpToNow: _noop,
          onBackTwoHours: _noop,
          onForwardTwoHours: _noop,
          onBackOneDay: _noop,
          onForwardOneDay: _noop,
          onZoomOut: _noop,
          onZoomIn: _noop,
          onResetZoom: _noop,
        ),
        body: const EpgAgendaResponsiveBody(
          compactChild: SizedBox.expand(key: ValueKey('compact-body')),
          desktopChild: SizedBox.expand(key: ValueKey('desktop-body')),
        ),
      ),
    ),
  );
}

void _setViewSize(WidgetTester tester, Size size) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
}

Widget _host({
  required double width,
  required double height,
  required double textScaleFactor,
  required Widget child,
}) {
  return MaterialApp(
    theme: AppTheme.darkTheme,
    builder: (context, appChild) => MediaQuery(
      data: MediaQuery.of(
        context,
      ).copyWith(textScaler: TextScaler.linear(textScaleFactor)),
      child: appChild!,
    ),
    home: Scaffold(
      body: Align(
        alignment: Alignment.topLeft,
        child: SizedBox(width: width, height: height, child: child),
      ),
    ),
  );
}

class _ToolbarCallbacks {
  const _ToolbarCallbacks({
    this.onJumpToNow = _noop,
    this.onBackTwoHours = _noop,
    this.onForwardTwoHours = _noop,
    this.onBackOneDay = _noop,
    this.onForwardOneDay = _noop,
    this.onZoomOut = _noop,
    this.onZoomIn = _noop,
    this.onResetZoom = _noop,
  });

  factory _ToolbarCallbacks.recording(List<EpgToolbarAction> invoked) =>
      _ToolbarCallbacks(
        onJumpToNow: () => invoked.add(EpgToolbarAction.now),
        onBackTwoHours: () => invoked.add(EpgToolbarAction.backTwoHours),
        onForwardTwoHours: () => invoked.add(EpgToolbarAction.forwardTwoHours),
        onBackOneDay: () => invoked.add(EpgToolbarAction.backOneDay),
        onForwardOneDay: () => invoked.add(EpgToolbarAction.forwardOneDay),
        onZoomOut: () => invoked.add(EpgToolbarAction.zoomOut),
        onZoomIn: () => invoked.add(EpgToolbarAction.zoomIn),
        onResetZoom: () => invoked.add(EpgToolbarAction.resetZoom),
      );

  final VoidCallback onJumpToNow;
  final VoidCallback onBackTwoHours;
  final VoidCallback onForwardTwoHours;
  final VoidCallback onBackOneDay;
  final VoidCallback onForwardOneDay;
  final VoidCallback onZoomOut;
  final VoidCallback onZoomIn;
  final VoidCallback onResetZoom;
}

void _noop() {}

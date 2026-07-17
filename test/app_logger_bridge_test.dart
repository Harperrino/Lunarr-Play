import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:m3uxtream_player/core/logger/app_error_handlers.dart';
import 'package:m3uxtream_player/core/logger/app_logger.dart';
import 'package:m3uxtream_player/features/diagnostics/providers/ui_logs_providers.dart';

void main() {
  setUp(() {
    AppLogger.clearHistory();
  });

  test('mirrors AppLogger events into the ui log console', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    container.read(uiLogsProvider);

    AppLogger.info(
      'Player connected to http://user:pass@iptv.example.com/live/user/pass/1?token=abc',
    );

    await Future<void>.delayed(Duration.zero);

    final logs = container.read(uiLogsProvider);
    expect(logs.last, contains('AppLogger[INFO]'));
    expect(logs.last, contains('Player connected'));
    expect(logs.last, isNot(contains('user:pass')));
    expect(logs.last, isNot(contains('token=abc')));
  });

  test('forwards Flutter errors into the ui log console', () async {
    final restorer = installAppErrorHandlers();
    addTearDown(restorer.restore);

    final container = ProviderContainer();
    addTearDown(container.dispose);

    container.read(uiLogsProvider);

    FlutterError.onError?.call(
      FlutterErrorDetails(
        exception: StateError(
          'Failed to open http://user:pass@iptv.example.com/live/user/pass/1?token=abc',
        ),
        stack: StackTrace.current,
        library: 'test',
        context: ErrorDescription('while rendering'),
      ),
    );

    await Future<void>.delayed(Duration.zero);

    final logs = container.read(uiLogsProvider);
    expect(logs.last, contains('FlutterError'));
    expect(logs.last, isNot(contains('user:pass')));
    expect(logs.last, isNot(contains('token=abc')));
  });

  test(
    'forwards Flutter error details including library, context, and collector info',
    () async {
      final restorer = installAppErrorHandlers();
      addTearDown(restorer.restore);

      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(uiLogsProvider);

      FlutterError.onError?.call(
        FlutterErrorDetails(
          exception: StateError(
            'RenderFlex overflowed by 18 pixels on the bottom.',
          ),
          stack: StackTrace.current,
          library: 'rendering library',
          context: ErrorDescription('while laying out a widget'),
          informationCollector: () sync* {
            yield ErrorDescription('The relevant error-causing widget was:');
            yield ErrorDescription('Column');
            yield ErrorDescription(
              'Column:file:///app/features/player/widgets/player_panel.dart:123',
            );
          },
        ),
      );

      await Future<void>.delayed(Duration.zero);

      final logs = container.read(uiLogsProvider);
      expect(logs.last, contains('FlutterError'));
      expect(logs.last, contains('library: rendering library'));
      expect(logs.last, contains('context: while laying out a widget'));
      expect(logs.last, contains('The relevant error-causing widget was:'));
      expect(logs.last, isNot(contains('user:pass')));
    },
  );

  test('restores previous Flutter and platform error handlers', () {
    final originalFlutterHandler = FlutterError.onError;
    final originalPlatformHandler = PlatformDispatcher.instance.onError;
    final originalErrorWidgetBuilder = ErrorWidget.builder;

    void customFlutterHandler(FlutterErrorDetails details) {}

    bool customPlatformHandler(Object error, StackTrace stack) => true;

    FlutterError.onError = customFlutterHandler;
    PlatformDispatcher.instance.onError = customPlatformHandler;

    final restorer = installAppErrorHandlers();
    addTearDown(() {
      restorer.restore();
      FlutterError.onError = originalFlutterHandler;
      PlatformDispatcher.instance.onError = originalPlatformHandler;
      ErrorWidget.builder = originalErrorWidgetBuilder;
    });

    expect(identical(FlutterError.onError, customFlutterHandler), isFalse);
    expect(
      identical(PlatformDispatcher.instance.onError, customPlatformHandler),
      isFalse,
    );

    restorer.restore();

    expect(identical(FlutterError.onError, customFlutterHandler), isTrue);
    expect(
      identical(PlatformDispatcher.instance.onError, customPlatformHandler),
      isTrue,
    );
    expect(identical(ErrorWidget.builder, originalErrorWidgetBuilder), isTrue);
  });

  testWidgets('uses a compact non-debug fallback for failed widget subtrees', (
    tester,
  ) async {
    final restorer = installAppErrorHandlers();
    addTearDown(restorer.restore);

    await tester.pumpWidget(
      SizedBox(
        width: 1000,
        height: 700,
        child: ErrorWidget.builder(
          FlutterErrorDetails(exception: StateError('private details')),
        ),
      ),
    );

    final fallback = find.byKey(const ValueKey('app-error-fallback'));
    expect(fallback, findsOneWidget);
    expect(tester.getSize(fallback).width, lessThanOrEqualTo(420));
    expect(find.textContaining('private details'), findsNothing);
    expect(find.text('This area could not be displayed.'), findsOneWidget);
    restorer.restore();
    expect(tester.takeException(), isNull);
  });
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:m3uxtream_player/shared/theme/app_theme.dart';
import 'package:m3uxtream_player/shared/widgets/app_surface.dart';
import 'package:m3uxtream_player/shared/widgets/media/media_metadata_row.dart';
import 'package:m3uxtream_player/shared/widgets/media/media_poster_frame.dart';
import 'package:m3uxtream_player/shared/widgets/media/media_progress_indicator.dart';

Widget _host(Widget child) => MaterialApp(
  theme: AppTheme.darkTheme,
  home: Scaffold(body: Center(child: child)),
);

void main() {
  testWidgets('poster frame keeps its public 2:3 layout contract', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        const SizedBox(
          width: 180,
          child: MediaPosterFrame(
            semanticLabel: 'Example movie',
            poster: ColoredBox(color: Colors.blue),
          ),
        ),
      ),
    );

    final size = tester.getSize(find.byType(MediaPosterFrame));
    expect(size.width / size.height, closeTo(2 / 3, 0.001));
    expect(tester.getSize(find.byType(AspectRatio)), size);
  });

  testWidgets(
    'poster frame keeps a visible tonal inset around full-bleed art',
    (tester) async {
      await tester.pumpWidget(
        _host(
          const SizedBox(
            width: 180,
            child: MediaPosterFrame(
              semanticLabel: 'Inset example',
              poster: ColoredBox(color: Colors.blue),
            ),
          ),
        ),
      );

      final inset = tester.widget<Padding>(
        find.byKey(const ValueKey('media-poster-frame-inset')),
      );
      expect(inset.padding, const EdgeInsets.all(2));
      expect(find.byType(ClipRRect), findsOneWidget);
    },
  );

  testWidgets(
    'poster activates by semantics tap and keyboard and exposes state',
    (tester) async {
      var activations = 0;
      final focusNode = FocusNode();
      addTearDown(focusNode.dispose);
      final semantics = tester.ensureSemantics();

      await tester.pumpWidget(
        _host(
          SizedBox(
            width: 180,
            child: MediaPosterFrame(
              semanticLabel: 'Selected movie',
              isSelected: true,
              focusNode: focusNode,
              onActivate: () => activations += 1,
              poster: const ColoredBox(color: Colors.blue),
            ),
          ),
        ),
      );

      expect(
        tester.getSemantics(find.byType(MediaPosterFrame)),
        matchesSemantics(
          label: 'Selected movie',
          isButton: true,
          isSelected: true,
          hasSelectedState: true,
          hasEnabledState: true,
          isEnabled: true,
          isFocusable: true,
          hasTapAction: true,
          hasFocusAction: true,
        ),
      );
      expect(
        tester.widget<AppSurface>(find.byType(AppSurface)).states,
        contains(WidgetState.selected),
      );

      await tester.tap(find.byType(MediaPosterFrame));
      expect(activations, 1);

      focusNode.requestFocus();
      await tester.pump();
      expect(
        tester.widget<AppSurface>(find.byType(AppSurface)).states,
        contains(WidgetState.focused),
      );

      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      expect(activations, 2);
      semantics.dispose();
    },
  );

  testWidgets('poster reports pressed state while the pointer is down', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        SizedBox(
          width: 180,
          child: MediaPosterFrame(
            semanticLabel: 'Example movie',
            onActivate: () {},
            poster: const ColoredBox(color: Colors.blue),
          ),
        ),
      ),
    );

    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(MediaPosterFrame)),
    );
    await tester.pump();
    expect(
      tester.widget<AppSurface>(find.byType(AppSurface)).states,
      contains(WidgetState.pressed),
    );

    await gesture.up();
    await tester.pump();
    expect(
      tester.widget<AppSurface>(find.byType(AppSurface)).states,
      isNot(contains(WidgetState.pressed)),
    );
  });

  testWidgets(
    'metadata title and subtitle ellipsize while badges remain tonal',
    (tester) async {
      const title = 'An intentionally long movie title that must truncate';
      const subtitle = 'An intentionally long subtitle that must also truncate';
      await tester.pumpWidget(
        _host(
          const SizedBox(
            width: 180,
            child: MediaMetadataRow(
              title: title,
              subtitle: subtitle,
              badges: <MediaMetadataBadge>[
                MediaMetadataBadge(label: '4K'),
                MediaMetadataBadge(label: '2026'),
              ],
            ),
          ),
        ),
      );

      final texts = tester.widgetList<Text>(find.byType(Text));
      expect(
        texts.singleWhere((text) => text.data == title).overflow,
        TextOverflow.ellipsis,
      );
      expect(
        texts.singleWhere((text) => text.data == subtitle).overflow,
        TextOverflow.ellipsis,
      );
      expect(find.bySemanticsLabel('4K'), findsOneWidget);
      expect(find.bySemanticsLabel('2026'), findsOneWidget);
    },
  );

  testWidgets('progress represents empty partial and complete resume states', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      _host(
        const Column(
          children: <Widget>[
            MediaProgressIndicator(progress: 0),
            MediaProgressIndicator(
              progress: 0.5,
              semanticLabel: 'Half watched',
            ),
            MediaProgressIndicator(progress: 1),
          ],
        ),
      ),
    );

    final indicators = tester.widgetList<LinearProgressIndicator>(
      find.byType(LinearProgressIndicator),
    );
    expect(indicators.map((indicator) => indicator.value), <double?>[
      0,
      0.5,
      1,
    ]);
    expect(
      tester.getSemantics(find.byType(MediaProgressIndicator).at(1)),
      matchesSemantics(label: 'Half watched', value: '50%'),
    );
    semantics.dispose();
  });
}

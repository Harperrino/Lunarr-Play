import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:m3uxtream_player/shared/widgets/app_brand_mark.dart';

void main() {
  testWidgets('brand mark renders the canonical standalone logo asset', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: Center(child: AppBrandMark(size: 40))),
      ),
    );

    final image = tester.widget<Image>(find.byKey(AppBrandMark.imageKey));
    expect(image.image, isA<AssetImage>());
    expect((image.image as AssetImage).assetName, AppBrandAssets.logo);
    expect(tester.getSize(find.byType(AppBrandMark)), const Size.square(40));
    expect(image.semanticLabel, 'Lunarr Player');
    expect(tester.takeException(), isNull);
  });

  testWidgets('brand wordmark preserves the supplied artwork aspect ratio', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: AppBrandWordmark(width: 187))),
    );

    final image = tester.widget<Image>(find.byKey(AppBrandWordmark.imageKey));
    expect(image.image, isA<AssetImage>());
    expect((image.image as AssetImage).assetName, AppBrandAssets.wordmark);
    expect(
      tester.getSize(find.byType(AppBrandWordmark)),
      const Size(187, 187 / AppBrandWordmark.aspectRatio),
    );
    expect(tester.takeException(), isNull);
  });
}

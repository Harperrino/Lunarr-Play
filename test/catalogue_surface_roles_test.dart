import 'package:flutter_test/flutter_test.dart';
import 'package:m3uxtream_player/shared/theme/app_theme.dart';
import 'package:m3uxtream_player/shared/theme/catalogue_surface_roles.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'catalogue empty and shimmer roles follow the Material color scheme',
    () {
      final theme = AppTheme.darkTheme;
      final colors = theme.colorScheme;
      final roles = CatalogueSurfaceRoles.fromTheme(theme);

      expect(roles.iconContainerStart, colors.primaryContainer);
      expect(roles.iconContainerEnd, colors.secondaryContainer);
      expect(roles.iconContainerBorder, colors.outlineVariant);
      expect(roles.onIconContainer, colors.onPrimaryContainer);
      expect(roles.subtitle, colors.onSurfaceVariant);
      expect(roles.shimmerBase, colors.surfaceContainerLow);
      expect(roles.shimmerHighlight, colors.surfaceContainerHighest);
      expect(roles.shimmerTile, colors.surfaceContainer);
    },
  );
}

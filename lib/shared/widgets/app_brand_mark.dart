import 'package:flutter/material.dart';

/// Code-native presentation of the LUNARR One application mark.
///
/// The mark deliberately resolves its accent from the active [ColorScheme] so
/// it follows appearance changes without loading or recoloring an image asset.
class AppBrandMark extends StatelessWidget {
  const AppBrandMark({super.key, this.size = 28, this.color});

  static const painterKey = ValueKey('app-brand-logo-painter');

  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final accent = color ?? colors.primary;
    final background = Color.alphaBlend(
      accent.withValues(alpha: 0.14),
      colors.surfaceContainerLow,
    );

    return SizedBox.square(
      dimension: size,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(size * 0.26),
        ),
        child: CustomPaint(
          key: painterKey,
          painter: LunarrBrandMarkPainter(color: accent),
        ),
      ),
    );
  }
}

/// Paints the LUNARR One crescent inside a compact display outline.
///
/// Keeping the painter public makes the color contract directly testable and
/// allows future platform surfaces to reuse the same vector geometry.
class LunarrBrandMarkPainter extends CustomPainter {
  const LunarrBrandMarkPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final extent = size.shortestSide;
    final strokeWidth = extent * 0.065;
    final linePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final displayRect = Rect.fromLTRB(
      extent * 0.16,
      extent * 0.17,
      extent * 0.84,
      extent * 0.66,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(displayRect, Radius.circular(extent * 0.09)),
      linePaint,
    );

    final standPath = Path()
      ..moveTo(extent * 0.50, extent * 0.67)
      ..lineTo(extent * 0.50, extent * 0.77)
      ..moveTo(extent * 0.36, extent * 0.80)
      ..lineTo(extent * 0.64, extent * 0.80);
    canvas.drawPath(standPath, linePaint);

    final moonOuter = Path()
      ..addOval(
        Rect.fromCircle(
          // The cutout removes the upper-right visual mass. Offset the source
          // circle so the remaining crescent is optically centered in-screen.
          center: Offset(extent * 0.52, extent * 0.39),
          radius: extent * 0.14,
        ),
      );
    final moonCutout = Path()
      ..addOval(
        Rect.fromCircle(
          center: Offset(extent * 0.59, extent * 0.35),
          radius: extent * 0.135,
        ),
      );
    final crescent = Path.combine(
      PathOperation.difference,
      moonOuter,
      moonCutout,
    );
    canvas.drawPath(crescent, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant LunarrBrandMarkPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}

import 'package:material_ui/material_ui.dart';
import 'package:shimmer/shimmer.dart';

/// App-level Shimmer boundary with a shared reduced-motion contract.
class AppShimmer extends StatelessWidget {
  const AppShimmer({
    super.key,
    required this.baseColor,
    required this.highlightColor,
    required this.child,
    this.enabled = true,
    this.period = const Duration(milliseconds: 1500),
  });

  final Color baseColor;
  final Color highlightColor;
  final Widget child;
  final bool enabled;
  final Duration period;

  @override
  Widget build(BuildContext context) {
    final animationEnabled =
        enabled && !MediaQuery.disableAnimationsOf(context);
    return TickerMode(
      key: const ValueKey('app-shimmer-ticker-mode'),
      enabled: animationEnabled,
      child: Shimmer.fromColors(
        baseColor: baseColor,
        highlightColor: highlightColor,
        enabled: animationEnabled,
        period: period,
        child: child,
      ),
    );
  }
}

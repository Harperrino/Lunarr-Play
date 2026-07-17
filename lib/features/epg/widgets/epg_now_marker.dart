import 'package:flutter/material.dart';
import 'package:m3uxtream_player/shared/theme/app_status_colors.dart';

/// Explicit current-time marker: status color plus icon and readable label.
class EpgNowMarker extends StatelessWidget {
  const EpgNowMarker({super.key});

  @override
  Widget build(BuildContext context) {
    final status = Theme.of(context).extension<AppStatusColors>()!;
    return Semantics(
      label: 'Jetzt, aktuelle Zeit im Programm',
      child: ExcludeSemantics(
        child: SizedBox(
          width: 2,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(child: ColoredBox(color: status.live)),
              Positioned(
                top: 6,
                left: -8,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: status.liveContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 5,
                      vertical: 3,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.radio_rounded,
                          size: 10,
                          color: status.onLiveContainer,
                        ),
                        const SizedBox(width: 3),
                        Text(
                          'JETZT',
                          style: TextStyle(
                            color: status.onLiveContainer,
                            fontSize: 8,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

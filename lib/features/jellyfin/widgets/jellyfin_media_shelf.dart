import 'package:flutter/material.dart';

const double jellyfinShelfCardWidth = 150;

/// Horizontally scrolling media section. Rendered by its parent only when
/// [children] is non-empty, so empty shelves never leave placeholders.
class JellyfinMediaShelf extends StatelessWidget {
  const JellyfinMediaShelf({
    super.key,
    required this.title,
    required this.children,
    this.trailing,
  });

  final String title;
  final List<Widget> children;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child:           Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              ?trailing,
            ],
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: jellyfinShelfCardWidth * 1.5 + 68,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: children.length,
            separatorBuilder: (_, _) => const SizedBox(width: 14),
            itemBuilder: (context, index) => SizedBox(
              width: jellyfinShelfCardWidth,
              child: children[index],
            ),
          ),
        ),
      ],
    );
  }
}

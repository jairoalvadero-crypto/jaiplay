import 'dart:math';

import 'package:flutter/material.dart';

import 'theme.dart';

/// Fila horizontal con titulo. Si hay mas de [limit] elementos, tocar el
/// titulo despliega todo en cuadricula.
class Shelf extends StatelessWidget {
  final String title;
  final int count;
  final int limit;
  final double collapsedWidth;
  final double inset;
  final double Function(double w) heightOf;
  final Widget Function(int i, double w) itemBuilder;
  final bool expanded;
  final VoidCallback? onToggle;

  const Shelf({
    super.key,
    required this.title,
    required this.count,
    required this.collapsedWidth,
    required this.heightOf,
    required this.itemBuilder,
    this.limit = 1000,
    this.inset = 20,
    this.expanded = false,
    this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final canExpand = onToggle != null && count > limit;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(inset, 24, inset, 12),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: canExpand ? onToggle : null,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(child: Text(title, style: kH2)),
                if (canExpand) ...[
                  const SizedBox(width: 6),
                  Icon(
                    expanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    color: kAccent,
                  ),
                ],
              ],
            ),
          ),
        ),
        LayoutBuilder(
          builder: (context, c) {
            final w3 = (c.maxWidth - 2 * inset - 24) / 3;
            return AnimatedSize(
              duration: const Duration(milliseconds: 250),
              alignment: Alignment.topCenter,
              child: expanded
                  ? Padding(
                      padding: EdgeInsets.symmetric(horizontal: inset),
                      child: Wrap(
                        spacing: 12,
                        runSpacing: 16,
                        children: [
                          for (var i = 0; i < count; i++) itemBuilder(i, w3),
                        ],
                      ),
                    )
                  : SizedBox(
                      height: heightOf(collapsedWidth),
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        padding: EdgeInsets.only(left: inset, right: 8),
                        itemCount: min(count, limit),
                        itemBuilder: (_, i) => Padding(
                          padding: const EdgeInsets.only(right: 12),
                          child: itemBuilder(i, collapsedWidth),
                        ),
                      ),
                    ),
            );
          },
        ),
      ],
    );
  }
}

import 'package:flutter/material.dart';

import '../../app/theme/strata_palette.dart';

/// RichText that highlights case-insensitive matches of [query] with a subtle
/// gold background, matching the Strata accent palette.
class HighlightText extends StatelessWidget {
  const HighlightText(
    this.text, {
    super.key,
    this.query = '',
    this.style,
    this.maxLines,
    this.overflow,
  });

  final String text;
  final String query;
  final TextStyle? style;
  final int? maxLines;
  final TextOverflow? overflow;

  @override
  Widget build(BuildContext context) {
    if (query.trim().isEmpty) {
      return Text(
        text,
        style: style,
        maxLines: maxLines,
        overflow: overflow,
      );
    }
    final spans = _buildSpans(text, query.trim());
    return RichText(
      maxLines: maxLines ?? 1,
      overflow: overflow ?? TextOverflow.ellipsis,
      text: TextSpan(children: spans, style: style),
    );
  }
}

List<TextSpan> _buildSpans(String text, String query) {
  final lower = text.toLowerCase();
  final queryLower = query.toLowerCase();
  final spans = <TextSpan>[];
  var start = 0;

  while (start < text.length) {
    final idx = lower.indexOf(queryLower, start);
    if (idx == -1) {
      spans.add(TextSpan(text: text.substring(start)));
      break;
    }
    if (idx > start) {
      spans.add(TextSpan(text: text.substring(start, idx)));
    }
    spans.add(
      TextSpan(
        text: text.substring(idx, idx + query.length),
        style: TextStyle(
          backgroundColor: StrataPalette.amber.withValues(alpha: .22),
          color: StrataPalette.amber,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
    start = idx + query.length;
  }
  return spans;
}

import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';

import '../../app/theme/strata_palette.dart';

/// A page-break divider embedded in a note. Stored as a plain block embed so
/// it survives delta JSON round-trips; rendered as a thin horizontal line.
class StrataDividerEmbed extends BlockEmbed {
  StrataDividerEmbed() : super(dividerType, 'line');

  static const String dividerType = 'divider';
}

class StrataDividerEmbedBuilder extends EmbedBuilder {
  const StrataDividerEmbedBuilder();

  @override
  String get key => StrataDividerEmbed.dividerType;

  @override
  Widget build(BuildContext context, EmbedContext embedContext) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: SizedBox(
        height: 12,
        child: Center(
          child: Container(
            height: 1.5,
            margin: const EdgeInsets.symmetric(horizontal: 4),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(2),
              gradient: LinearGradient(
                colors: [
                  StrataPalette.onSurfaceMuted.withValues(alpha: .04),
                  StrataPalette.onSurfaceMuted.withValues(alpha: .3),
                  StrataPalette.onSurfaceMuted.withValues(alpha: .04),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

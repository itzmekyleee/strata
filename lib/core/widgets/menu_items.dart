import 'package:flutter/material.dart';

import '../../app/theme/strata_palette.dart';

/// A row for popup menus: tinted icon bubble + label + optional trailing
/// widget. Wrap in a [PopupMenuItem] via [strataPopupItem].
class StrataMenuRow extends StatelessWidget {
  const StrataMenuRow({
    super.key,
    required this.icon,
    required this.label,
    this.danger = false,
    this.enabled = true,
    this.trailing,
  });

  final IconData icon;
  final String label;

  /// Renders the row in the error color (destructive actions).
  final bool danger;

  /// When false the row is greyed out and un-interactive.
  final bool enabled;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final tint = danger ? StrataPalette.coral : StrataPalette.accent;
    return Row(
      children: [
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: danger
                ? StrataPalette.coral.withValues(alpha: .13)
                : StrataPalette.accent.withValues(alpha: .1),
            borderRadius: BorderRadius.circular(9),
          ),
          child: Icon(
            icon,
            size: 16,
            color: enabled
                ? (danger ? tint : StrataPalette.accent)
                : StrataPalette.onSurfaceDim,
          ),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
              color: enabled
                  ? (danger ? tint : StrataPalette.onBackground)
                  : StrataPalette.onSurfaceDim,
            ),
          ),
        ),
        ?trailing,
      ],
    );
  }
}

/// Convenience factory for a themed [PopupMenuItem].
PopupMenuItem<T> strataPopupItem<T>({
  required T value,
  required IconData icon,
  required String label,
  bool danger = false,
  bool enabled = true,
  Widget? trailing,
}) {
  return PopupMenuItem<T>(
    value: value,
    enabled: enabled,
    height: 46,
    padding: const EdgeInsets.symmetric(horizontal: 10),
    child: StrataMenuRow(
      icon: icon,
      label: label,
      danger: danger,
      enabled: enabled,
      trailing: trailing,
    ),
  );
}

/// Small uppercase section label for grouping menu entries.
class StrataMenuHeader extends StatelessWidget {
  const StrataMenuHeader(this.label, {super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 2),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.1,
          color: StrataPalette.onSurfaceMuted,
        ),
      ),
    );
  }
}

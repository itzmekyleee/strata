import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../app/theme/strata_palette.dart';

/// Animated, branded confirmation dialog for destructive actions (delete note,
/// empty trash, etc.).
///
/// Returns `true` when the user confirms. The dialog scales/fades in, and the
/// destructive button shakes once when the user first taps it — an accidental
/// tap can be reconsidered before the second tap actually confirms.
Future<bool> showConfirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Delete',
  String cancelLabel = 'Cancel',
  IconData? icon = Icons.delete_outline_rounded,
}) async {
  return await showDialog<bool>(
    context: context,
    barrierDismissible: true,
    barrierColor: Colors.black.withValues(alpha: .45),
    builder: (ctx) => _ConfirmDialog(
      title: title,
      message: message,
      confirmLabel: confirmLabel,
      cancelLabel: cancelLabel,
      icon: icon,
    ),
  ) ??
      false;
}

class _ConfirmDialog extends StatefulWidget {
  const _ConfirmDialog({
    required this.title,
    required this.message,
    required this.confirmLabel,
    required this.cancelLabel,
    this.icon,
  });

  final String title;
  final String message;
  final String confirmLabel;
  final String cancelLabel;
  final IconData? icon;

  @override
  State<_ConfirmDialog> createState() => _ConfirmDialogState();
}

class _ConfirmDialogState extends State<_ConfirmDialog> {
  bool _confirmArmed = false;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: StrataPalette.surfaceHigh,
      surfaceTintColor: Colors.transparent,
      elevation: 24,
      shadowColor: Colors.black.withValues(alpha: .45),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: BorderSide(color: StrataPalette.outline),
      ),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 380),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 18, 22, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  // Warning icon bubble — nudge when the user arms confirm.
                  AnimatedScale(
                    scale: _confirmArmed ? .92 : 1,
                    duration: const Duration(milliseconds: 140),
                    curve: Curves.easeOutBack,
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: StrataPalette.coral.withValues(alpha: .13),
                        borderRadius: BorderRadius.circular(13),
                      ),
                      child: Icon(
                        widget.icon ?? Icons.delete_outline_rounded,
                        size: 24,
                        color: StrataPalette.coral,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      widget.title,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        fontSize: 19,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.only(left: 58),
                child: Text(
                  widget.message,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: StrataPalette.onSurfaceMuted,
                    height: 1.45,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: Text(widget.cancelLabel),
                  ),
                  const SizedBox(width: 8),
                  _ConfirmButton(
                    armed: _confirmArmed,
                    icon: widget.icon ?? Icons.delete_outline_rounded,
                    label: _confirmArmed ? 'Tap to confirm' : widget.confirmLabel,
                    onPressed: () {
                      if (!_confirmArmed) {
                        setState(() => _confirmArmed = true);
                        return;
                      }
                      Navigator.of(context).pop(true);
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    )
        .animate(delay: 10.ms)
        .fadeIn(duration: 200.ms, curve: Curves.easeOutCubic)
        .scale(
          begin: const Offset(.94, .94),
          end: const Offset(1, 1),
          duration: 230.ms,
          curve: Curves.easeOutBack,
        );
  }
}

/// The destructive confirm button. Shakes horizontally the first time the user
/// taps it (arming), as a final warning before they tap again to confirm.
class _ConfirmButton extends StatefulWidget {
  const _ConfirmButton({
    required this.armed,
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final bool armed;
  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  State<_ConfirmButton> createState() => _ConfirmButtonState();
}

class _ConfirmButtonState extends State<_ConfirmButton> {
  bool _didShake = false;

  @override
  void didUpdateWidget(covariant _ConfirmButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Shake the moment the button becomes armed.
    if (widget.armed != oldWidget.armed && widget.armed) _didShake = false;
  }

  @override
  Widget build(BuildContext context) {
    final shake = widget.armed && !_didShake;
    _didShake = _didShake || shake;
    final button = FilledButton.icon(
      style: FilledButton.styleFrom(
        backgroundColor: StrataPalette.coral,
        foregroundColor: Colors.white,
        elevation: widget.armed ? 4 : 2,
        shadowColor: StrataPalette.coral.withValues(alpha: .5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
      ),
      onPressed: widget.onPressed,
      icon: Icon(widget.armed ? Icons.check_rounded : widget.icon, size: 18),
      label: Text(widget.label, style: const TextStyle(fontWeight: FontWeight.w700)),
    );

    return shake
        ? button.animate().shakeX(
              amount: 7,
              duration: 320.ms,
              curve: Curves.easeOut,
            )
        : button;
  }
}
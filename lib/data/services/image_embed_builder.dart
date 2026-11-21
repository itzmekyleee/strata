import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';

import 'attachment_storage.dart';

class StrataImageEmbedBuilder extends EmbedBuilder {
  const StrataImageEmbedBuilder({required this.storage, this.onOpenImage});

  final AttachmentStorage storage;
  final void Function(BuildContext context, File file)? onOpenImage;

  @override
  String get key => 'image';

  @override
  Widget build(BuildContext context, EmbedContext embedContext) {
    final data = embedContext.node.value.data as String;
    final file = storage.resolveEmbedSource(data);
    final theme = Theme.of(context);

    Widget child;
    if (file != null) {
      child = _SizedImage(
        file: file,
        onOpenImage: onOpenImage,
      );
    } else {
      child = _placeholder(theme);
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: GestureDetector(
        onTap: () {
          if (file != null) onOpenImage?.call(context, file);
        },
        child: child,
      ),
    );
  }

  Widget _placeholder(ThemeData theme) => Container(
    height: 120,
    decoration: BoxDecoration(
      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: .4),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(
        color: theme.colorScheme.outlineVariant.withValues(alpha: .5),
      ),
    ),
    alignment: Alignment.center,
    child: Icon(
      Icons.broken_image_outlined,
      color: theme.colorScheme.onSurfaceVariant,
    ),
  );
}

/// Reads the image file once to determine its natural dimensions, then renders
/// at the correct aspect ratio (capped at 320px tall).
class _SizedImage extends StatefulWidget {
  const _SizedImage({required this.file, this.onOpenImage});

  final File file;
  final void Function(BuildContext context, File file)? onOpenImage;

  @override
  State<_SizedImage> createState() => _SizedImageState();
}

class _SizedImageState extends State<_SizedImage> {
  double? _aspectRatio;

  @override
  void initState() {
    super.initState();
    _loadDimensions();
  }

  Future<void> _loadDimensions() async {
    try {
      final bytes = await widget.file.readAsBytes();
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      final w = frame.image.width.toDouble();
      final h = frame.image.height.toDouble();
      frame.image.dispose();
      if (mounted && w > 0 && h > 0) {
        setState(() => _aspectRatio = w / h);
      }
    } catch (_) {
      // Fallback: square placeholder if dimensions can't be read.
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final maxW = (screenWidth - 48).clamp(200.0, 860.0);

    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: _aspectRatio != null
          ? ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxW),
              child: AspectRatio(
                aspectRatio: _aspectRatio!,
                child: Image.file(
                  widget.file,
                  fit: BoxFit.contain,
                  errorBuilder: (_, _, _) => _errorPlaceholder,
                ),
              ),
            )
          : Container(
              height: 120,
              decoration: BoxDecoration(
                color: Theme.of(context)
                    .colorScheme
                    .surfaceContainerHighest
                    .withValues(alpha: .4),
                borderRadius: BorderRadius.circular(14),
              ),
              alignment: Alignment.center,
              child: const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
    );
  }

  Widget get _errorPlaceholder => Container(
    height: 120,
    alignment: Alignment.center,
    child: const Icon(Icons.broken_image_outlined),
  );
}

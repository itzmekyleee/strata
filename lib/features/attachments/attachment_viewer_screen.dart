import 'dart:io';

import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../../app/router.dart';
import '../../app/theme/strata_palette.dart';
import '../../core/widgets/glass_card.dart';

class AttachmentViewerScreen extends StatelessWidget {
  const AttachmentViewerScreen({super.key, required this.args});

  final AttachmentViewArgs args;

  bool get _isImage =>
      args.path.toLowerCase().endsWith('.png') ||
      args.path.toLowerCase().endsWith('.jpg') ||
      args.path.toLowerCase().endsWith('.jpeg') ||
      args.path.toLowerCase().endsWith('.gif') ||
      args.path.toLowerCase().endsWith('.webp');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 20,
        title: Text(args.name),
        actions: [
          IconButton(
            tooltip: 'Share',
            icon: const Icon(Icons.ios_share_rounded),
            onPressed: () {
              SharePlus.instance.share(ShareParams(files: [XFile(args.path)]));
            },
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: Center(
        child: _isImage
            ? InteractiveViewer(
                maxScale: 5,
                child: Image.file(File(args.path), fit: BoxFit.contain),
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.insert_drive_file_outlined,
                    size: 60,
                    color: StrataPalette.accent.withValues(alpha: .8),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    args.name,
                    style: Theme.of(context).textTheme.titleMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Preview not supported — use share to open externally.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: StrataPalette.onSurfaceMuted,
                    ),
                  ),
                  const SizedBox(height: 18),
                  FilledButton.icon(
                    onPressed: () => SharePlus.instance.share(
                      ShareParams(files: [XFile(args.path)]),
                    ),
                    icon: const Icon(Icons.ios_share_rounded),
                    label: const Text('Open / Share'),
                  ),
                ],
              ),
      ),
    ).entrance(index: 0);
  }
}

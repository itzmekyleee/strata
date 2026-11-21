import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

import '../../app/theme/strata_palette.dart';

/// A single shimmer line (bar) used inside skeleton layouts.
class SkeletonBar extends StatelessWidget {
  const SkeletonBar({
    super.key,
    this.width,
    this.height = 14,
    this.borderRadius = 7,
  });

  final double? width;
  final double height;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: StrataPalette.surfaceHigh.withValues(alpha: .6),
        borderRadius: BorderRadius.circular(borderRadius),
      ),
    );
  }
}

/// A shimmering container that wraps children in a [Shimmer] gradient.
class SkeletonBox extends StatelessWidget {
  const SkeletonBox({
    super.key,
    required this.child,
    this.baseColor,
    this.highlightColor,
  });

  final Widget child;
  final Color? baseColor;
  final Color? highlightColor;

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: baseColor ?? StrataPalette.surfaceHigh.withValues(alpha: .6),
      highlightColor:
          highlightColor ?? StrataPalette.surfaceHighest.withValues(alpha: .5),
      child: child,
    );
  }
}

/// Mimics a [NoteTile] while data is loading.
class NoteTileSkeleton extends StatelessWidget {
  const NoteTileSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      child: SkeletonBox(
        child: Container(
          height: 82,
          decoration: BoxDecoration(
            color: StrataPalette.surfaceHigh,
            borderRadius: BorderRadius.circular(16),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SkeletonBar(width: 160, height: 14),
              const SizedBox(height: 8),
              SkeletonBar(width: 240, height: 11),
              const SizedBox(height: 10),
              Row(
                children: [
                  SkeletonBar(width: 70, height: 11),
                  const SizedBox(width: 8),
                  SkeletonBar(width: 60, height: 11),
                  const Spacer(),
                  SkeletonBar(width: 30, height: 6, borderRadius: 3),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A list of skeleton note tiles for the home screen.
class NoteListSkeleton extends StatelessWidget {
  const NoteListSkeleton({super.key, this.count = 6});

  final int count;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.only(top: 4, bottom: 96),
      itemCount: count,
      itemBuilder: (_, i) => NoteTileSkeleton(
        key: ValueKey('skeleton-$i'),
      ),
    );
  }
}

/// Skeleton for a single tag row.
class TagRowSkeleton extends StatelessWidget {
  const TagRowSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: SkeletonBox(
        child: Row(
          children: [
            SkeletonBar(width: 12, height: 12, borderRadius: 6),
            const SizedBox(width: 14),
            SkeletonBar(width: 100, height: 14),
            const Spacer(),
            SkeletonBar(width: 24, height: 14),
          ],
        ),
      ),
    );
  }
}

/// Skeleton for the folder tree sidebar.
class FolderTreeSkeleton extends StatelessWidget {
  const FolderTreeSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return SkeletonBox(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SkeletonBar(width: 80, height: 12),
            const SizedBox(height: 14),
            for (var i = 0; i < 5; i++) ...[
              Row(
                children: [
                  SkeletonBar(
                    width: 14,
                    height: 14,
                    borderRadius: 4,
                  ),
                  const SizedBox(width: 10),
                  SkeletonBar(width: 80.0 + i * 15, height: 13),
                ],
              ),
              if (i < 4) const SizedBox(height: 10),
            ],
          ],
        ),
      ),
    );
  }
}

/// Skeleton for the editor (title + body lines).
class EditorSkeleton extends StatelessWidget {
  const EditorSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return SkeletonBox(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SkeletonBar(width: 200, height: 22, borderRadius: 4),
            const SizedBox(height: 24),
            SkeletonBar(width: double.infinity, height: 13),
            const SizedBox(height: 12),
            SkeletonBar(width: 280, height: 13),
            const SizedBox(height: 12),
            SkeletonBar(width: 220, height: 13),
            const SizedBox(height: 20),
            SkeletonBar(width: 180, height: 13),
            const SizedBox(height: 12),
            SkeletonBar(width: 300, height: 13),
            const SizedBox(height: 12),
            SkeletonBar(width: 160, height: 13),
          ],
        ),
      ),
    );
  }
}

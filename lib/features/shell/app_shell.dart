import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme/strata_palette.dart';
import '../../app/theme/theme_variant.dart';
import '../../core/widgets/global_shortcuts.dart';

class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.shell});

  final StatefulNavigationShell shell;

  static const _destinations = [
    (
      Icons.sticky_note_2_outlined,
      Icons.sticky_note_2_rounded,
      'Notes',
    ),
    (
      Icons.event_note_outlined,
      Icons.event_note_rounded,
      'Planned',
    ),
    (
      Icons.delete_outline_rounded,
      Icons.delete_rounded,
      'Trash',
    ),
    (
      Icons.settings_outlined,
      Icons.settings_rounded,
      'Settings',
    ),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch the theme so navigation colors refresh immediately on theme changes.
    ref.watch(themeVariantProvider);
    final width = MediaQuery.sizeOf(context).width;

    if (width < 640) {
      return _ScaffoldBase(
        index: shell.currentIndex,
        bottom: _MobileTabBar(shell: shell),
        child: shell,
      );
    }
    if (width < 1024) {
      return _ScaffoldBase(
        index: shell.currentIndex,
        side: _TabletRail(shell: shell),
        child: shell,
      );
    }
    return _ScaffoldBase(
      index: shell.currentIndex,
      side: _DesktopSidebar(shell: shell),
      child: shell,
    );
  }
}

class _ScaffoldBase extends StatelessWidget {
  const _ScaffoldBase({
    required this.index,
    required this.child,
    this.side,
    this.bottom,
  });

  final int index;
  final Widget child;
  final Widget? side;
  final Widget? bottom;

  @override
  Widget build(BuildContext context) {
    return GlobalShortcuts(
      child: Scaffold(
        body: Row(
          children: [
            ?side,
            Expanded(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: side == null
                        ? const Alignment(-.8, -1)
                        : const Alignment(-.2, -1.1),
                    radius: 1.35,
                    colors: [StrataPalette.glow, StrataPalette.background],
                    stops: const [0, .5],
                  ),
                ),
                child: _SectionTransition(index: index, child: child),
              ),
            ),
          ],
        ),
        bottomNavigationBar: bottom,
      ),
    );
  }
}

class _SectionTransition extends StatefulWidget {
  const _SectionTransition({required this.index, required this.child});

  final int index;
  final Widget child;

  @override
  State<_SectionTransition> createState() => _SectionTransitionState();
}

class _SectionTransitionState extends State<_SectionTransition> {
  int? _previous;

  @override
  void didUpdateWidget(covariant _SectionTransition oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.index != widget.index) _previous = oldWidget.index;
  }

  @override
  Widget build(BuildContext context) {
    if (_previous == null) return widget.child;
    final forward = widget.index >= (_previous ?? 0);
    return Animate(
      key: ValueKey('section-${widget.index}'),
      effects: [
        FadeEffect(
          begin: .35,
          end: 1,
          duration: 220.ms,
          curve: Curves.easeOutCubic,
        ),
        SlideEffect(
          begin: Offset(0, forward ? .012 : -.012),
          end: Offset.zero,
          duration: 220.ms,
          curve: Curves.easeOutCubic,
        ),
      ],
      child: widget.child,
    );
  }
}

// ---------------------------------------------------------------------------
// Mobile: bottom navigation with sliding indicator
// ---------------------------------------------------------------------------
class _MobileTabBar extends StatelessWidget {
  const _MobileTabBar({required this.shell});

  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final count = AppShell._destinations.length;
    final index = shell.currentIndex;

    return SafeArea(
      top: false,
      child: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: Container(
            decoration: BoxDecoration(
              color: StrataPalette.surface.withValues(
                alpha: isDark ? .72 : .82,
              ),
              border: Border(
                top: BorderSide(color: StrataPalette.outlineStrong, width: .5),
              ),
            ),
            padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final itemWidth = constraints.maxWidth / count;
                const indicatorWidth = 56.0;
                const indicatorHeight = 36.0;
                final indicatorLeft =
                    index * itemWidth + (itemWidth - indicatorWidth) / 2;

                return SizedBox(
                  height: 58,
                  child: Stack(
                    children: [
                      AnimatedPositioned(
                        duration: const Duration(milliseconds: 320),
                        curve: Curves.easeOutCubic,
                        left: indicatorLeft,
                        top: 2,
                        width: indicatorWidth,
                        height: indicatorHeight,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: StrataPalette.accent.withValues(alpha: .14),
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),
                      Row(
                        children: [
                          for (var i = 0; i < count; i++)
                            Expanded(
                              child: _MobileTabItem(
                                shell: shell,
                                index: i,
                                icon: AppShell._destinations[i].$1,
                                activeIcon: AppShell._destinations[i].$2,
                                label: AppShell._destinations[i].$3,
                                selected: index == i,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _MobileTabItem extends StatelessWidget {
  const _MobileTabItem({
    required this.shell,
    required this.index,
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.selected,
  });

  final StatefulNavigationShell shell;
  final int index;
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final color = selected ? StrataPalette.accent : StrataPalette.onSurfaceMuted;
    return Semantics(
      selected: selected,
      button: true,
      label: label,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () {
          HapticFeedback.selectionClick();
          shell.goBranch(index, initialLocation: selected);
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedScale(
                scale: selected ? 1.0 : .96,
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                child: Icon(
                  selected ? activeIcon : icon,
                  size: 24,
                  color: color,
                ),
              ),
              const SizedBox(height: 4),
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  letterSpacing: .1,
                  color: color,
                ),
                child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Tablet: navigation rail with sliding indicator
// ---------------------------------------------------------------------------
class _TabletRail extends StatelessWidget {
  const _TabletRail({required this.shell});

  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context) {
    final index = shell.currentIndex;
    final count = AppShell._destinations.length;
    const itemHeight = 72.0;
    const indicatorHeight = 56.0;
    const indicatorWidth = 64.0;
    final topPadding = MediaQuery.paddingOf(context).top;

    return Container(
      width: 92,
      decoration: BoxDecoration(
        color: StrataPalette.surface.withValues(alpha: .56),
        border: Border(
          right: BorderSide(color: StrataPalette.outline),
        ),
      ),
      child: Column(
        children: [
          SizedBox(height: topPadding + 12),
          const _BrandMark(),
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: SizedBox(
              height: count * itemHeight,
              child: Stack(
                children: [
                  AnimatedPositioned(
                    duration: const Duration(milliseconds: 320),
                    curve: Curves.easeOutCubic,
                    top: index * itemHeight + (itemHeight - indicatorHeight) / 2,
                    left: (64 - indicatorWidth) / 2,
                    width: indicatorWidth,
                    height: indicatorHeight,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: StrataPalette.accent.withValues(alpha: .13),
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                  ),
                  Column(
                    children: [
                      for (var i = 0; i < count; i++)
                        SizedBox(
                          height: itemHeight,
                          child: _RailItem(
                            shell: shell,
                            index: i,
                            icon: AppShell._destinations[i].$1,
                            activeIcon: AppShell._destinations[i].$2,
                            label: AppShell._destinations[i].$3,
                            selected: index == i,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const Spacer(),
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Text(
              'v1.0',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: StrataPalette.onSurfaceMuted.withValues(alpha: .7),
                    fontSize: 10,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RailItem extends StatelessWidget {
  const _RailItem({
    required this.shell,
    required this.index,
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.selected,
  });

  final StatefulNavigationShell shell;
  final int index;
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final color = selected ? StrataPalette.accent : StrataPalette.onSurfaceMuted;
    return Semantics(
      selected: selected,
      button: true,
      label: label,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () {
          HapticFeedback.selectionClick();
          shell.goBranch(index, initialLocation: selected);
        },
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedScale(
                scale: selected ? 1.0 : .96,
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                child: Icon(selected ? activeIcon : icon, size: 24, color: color),
              ),
              const SizedBox(height: 6),
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: color,
                ),
                child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Desktop / large tablet landscape: sidebar with sliding indicator
// ---------------------------------------------------------------------------
class _DesktopSidebar extends StatelessWidget {
  const _DesktopSidebar({required this.shell});

  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context) {
    final index = shell.currentIndex;
    final count = AppShell._destinations.length;
    const itemHeight = 46.0;
    const itemGap = 4.0;
    const indicatorHeight = 42.0;
    final topPadding = MediaQuery.paddingOf(context).top;

    return Container(
      width: 244,
      decoration: BoxDecoration(
        color: StrataPalette.surface.withValues(alpha: .58),
        border: Border(
          right: BorderSide(color: StrataPalette.outline),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(height: topPadding + 12),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 18),
            child: _BrandMark(showName: true),
          ),
          const SizedBox(height: 28),
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 0, 22, 10),
            child: Text(
              'LIBRARY',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    fontSize: 10,
                    letterSpacing: 1.2,
                    color: StrataPalette.onSurfaceMuted,
                  ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: SizedBox(
              height: count * itemHeight + (count - 1) * itemGap,
              child: Stack(
                children: [
                  AnimatedPositioned(
                    duration: const Duration(milliseconds: 320),
                    curve: Curves.easeOutCubic,
                    top: index * (itemHeight + itemGap) + (itemHeight - indicatorHeight) / 2,
                    left: 0,
                    right: 0,
                    height: indicatorHeight,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: StrataPalette.accent.withValues(alpha: .11),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: StrataPalette.accent.withValues(alpha: .08),
                        ),
                      ),
                    ),
                  ),
                  Column(
                    children: [
                      for (var i = 0; i < count; i++) ...[
                        SizedBox(
                          height: itemHeight,
                          child: _SideItem(
                            shell: shell,
                            index: i,
                            icon: AppShell._destinations[i].$1,
                            activeIcon: AppShell._destinations[i].$2,
                            label: AppShell._destinations[i].$3,
                            selected: index == i,
                          ),
                        ),
                        if (i != count - 1) const SizedBox(height: itemGap),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
          const Spacer(),
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 0, 22, 20),
            child: Text(
              'v1.0.0 · local-first',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    letterSpacing: .3,
                    color: StrataPalette.onSurfaceMuted.withValues(alpha: .7),
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SideItem extends StatelessWidget {
  const _SideItem({
    required this.shell,
    required this.index,
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.selected,
  });

  final StatefulNavigationShell shell;
  final int index;
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final color = selected ? StrataPalette.accent : StrataPalette.onSurfaceMuted;
    return Semantics(
      selected: selected,
      button: true,
      label: label,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () {
          HapticFeedback.selectionClick();
          shell.goBranch(index, initialLocation: selected);
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Row(
            children: [
              AnimatedScale(
                scale: selected ? 1.0 : .96,
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                child: Icon(selected ? activeIcon : icon, size: 20, color: color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOutCubic,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    letterSpacing: .1,
                    color: color,
                  ),
                  child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BrandMark extends StatelessWidget {
  const _BrandMark({this.showName = false});

  final bool showName;

  @override
  Widget build(BuildContext context) {
    final mark = Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1C1A16), Color(0xFF0A0908)],
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(6.5),
        child: Image.asset('assets/icons/ic_foreground.png'),
      ),
    );

    if (!showName) return Center(child: mark);

    return Row(
      children: [
        mark,
        const SizedBox(width: 11),
        Text(
          'Strata',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
        ),
      ],
    );
  }
}

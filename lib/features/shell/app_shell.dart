import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme/strata_palette.dart';
import '../../app/theme/theme_variant.dart';
import '../../core/widgets/global_shortcuts.dart';
import '../../providers/core_providers.dart';
import '../../providers/folder_counts.dart';
import '../../providers/notes_providers.dart';
import '../editor/editor_screen.dart';
import '../home/widgets/folder_tree.dart';
import '../templates/template_picker_sheet.dart';

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
    final size = MediaQuery.sizeOf(context);
    final width = size.width;
    final isLandscape = size.width > size.height;

    if (width >= 1100 && isLandscape) {
      return _TabletLandscapeShell(shell: shell);
    }

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
// Mobile: floating bottom navigation with sliding indicator and create button
// ---------------------------------------------------------------------------
class _MobileTabBar extends ConsumerWidget {
  const _MobileTabBar({required this.shell});

  final StatefulNavigationShell shell;

  static int _visualSlotForBranch(int branch) {
    return switch (branch) {
      0 => 0,
      1 => 1,
      2 => 3,
      3 => 4,
      _ => 0,
    };
  }

  Future<void> _createNote(BuildContext context, WidgetRef ref) async {
    HapticFeedback.mediumImpact();
    final folderId = ref.read(selectedFolderProvider);
    final choice = await showTemplatePickerSheet(context, ref);
    if (choice == null || !context.mounted) return;
    final note = await ref.read(noteActionsProvider).createNote(
          folderId: folderId,
          title: choice.title,
          contentDelta: choice.deltaJson,
        );
    if (!context.mounted) return;
    final isThreePane = MediaQuery.sizeOf(context).width >= 1100 &&
        MediaQuery.sizeOf(context).width > MediaQuery.sizeOf(context).height;
    if (isThreePane) {
      ref.read(selectedNoteIdProvider.notifier).select(note.id);
    } else {
      await context.push('/editor/${note.id}');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final branch = shell.currentIndex;
    final visualSlot = _visualSlotForBranch(branch);
    const slotCount = 5;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
            child: Container(
              height: 68,
              decoration: BoxDecoration(
                color: StrataPalette.surface.withValues(alpha: isDark ? .22 : .14),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: StrataPalette.outlineStrong.withValues(alpha: .5), width: .7),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? .22 : .12),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final itemWidth = constraints.maxWidth / slotCount;
                  const indicatorWidth = 52.0;
                  const indicatorHeight = 52.0;
                  final indicatorLeft =
                      visualSlot * itemWidth + (itemWidth - indicatorWidth) / 2;

                  return Stack(
                    children: [
                      AnimatedPositioned(
                        duration: const Duration(milliseconds: 320),
                        curve: Curves.easeOutCubic,
                        left: indicatorLeft,
                        top: (constraints.maxHeight - indicatorHeight) / 2,
                        width: indicatorWidth,
                        height: indicatorHeight,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: StrataPalette.accent.withValues(alpha: .14),
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      ),
                      Row(
                        children: [
                          Expanded(
                            child: _MobileTabItem(
                              shell: shell,
                              index: 0,
                              icon: AppShell._destinations[0].$1,
                              activeIcon: AppShell._destinations[0].$2,
                              label: AppShell._destinations[0].$3,
                              selected: branch == 0,
                            ),
                          ),
                          Expanded(
                            child: _MobileTabItem(
                              shell: shell,
                              index: 1,
                              icon: AppShell._destinations[1].$1,
                              activeIcon: AppShell._destinations[1].$2,
                              label: AppShell._destinations[1].$3,
                              selected: branch == 1,
                            ),
                          ),
                          Expanded(
                            child: _MobileCreateButton(
                              onTap: () => _createNote(context, ref),
                            ),
                          ),
                          Expanded(
                            child: _MobileTabItem(
                              shell: shell,
                              index: 2,
                              icon: AppShell._destinations[2].$1,
                              activeIcon: AppShell._destinations[2].$2,
                              label: AppShell._destinations[2].$3,
                              selected: branch == 2,
                            ),
                          ),
                          Expanded(
                            child: _MobileTabItem(
                              shell: shell,
                              index: 3,
                              icon: AppShell._destinations[3].$1,
                              activeIcon: AppShell._destinations[3].$2,
                              label: AppShell._destinations[3].$3,
                              selected: branch == 3,
                            ),
                          ),
                        ],
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MobileCreateButton extends StatelessWidget {
  const _MobileCreateButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Create note',
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Center(
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: StrataPalette.accent,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: StrataPalette.accent.withValues(alpha: .35),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Icon(Icons.add_rounded, color: Colors.white, size: 26),
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
                  size: 22,
                  color: color,
                ),
              ),
              const SizedBox(height: 2),
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                style: TextStyle(
                  fontSize: 10,
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


// ---------------------------------------------------------------------------
// Tablet landscape: 3-pane layout (20% nav / 30% list / 50% editor)
// ---------------------------------------------------------------------------
class _TabletLandscapeShell extends ConsumerStatefulWidget {
  const _TabletLandscapeShell({required this.shell});

  final StatefulNavigationShell shell;

  @override
  ConsumerState<_TabletLandscapeShell> createState() => _TabletLandscapeShellState();
}

class _TabletLandscapeShellState extends ConsumerState<_TabletLandscapeShell> {
  bool _editorExpanded = false;

  @override
  Widget build(BuildContext context) {
    final selectedNoteId = ref.watch(selectedNoteIdProvider);
    final shell = widget.shell;

    if (_editorExpanded && selectedNoteId == null) {
      _editorExpanded = false;
    }

    return GlobalShortcuts(
      child: Scaffold(
        body: DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: const Alignment(-.2, -1.1),
              radius: 1.35,
              colors: [StrataPalette.glow, StrataPalette.background],
              stops: const [0, .5],
            ),
          ),
          child: Row(
            children: [
              if (!_editorExpanded) ...[
                Expanded(
                  flex: 20,
                  child: _LeftNavPane(shell: shell),
                ),
                VerticalDivider(width: 1, color: StrataPalette.outline),
              ],
              if (shell.currentIndex == 3)
                Expanded(
                  flex: _editorExpanded ? 100 : 80,
                  child: _MiddlePane(shell: shell),
                )
              else ...[
                if (!_editorExpanded) ...[
                  Expanded(
                    flex: 30,
                    child: _MiddlePane(shell: shell),
                  ),
                  VerticalDivider(width: 1, color: StrataPalette.outline),
                ],
                Expanded(
                  flex: _editorExpanded ? 100 : 50,
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: selectedNoteId != null
                            ? EditorScreen(
                                key: ValueKey('editor-$selectedNoteId'),
                                noteId: selectedNoteId,
                                onClose: () {
                                  ref.read(selectedNoteIdProvider.notifier).select(null);
                                  setState(() => _editorExpanded = false);
                                },
                              )
                            : const _EditorPlaceholderPane(),
                      ),
                      if (selectedNoteId != null)
                        Positioned(
                          top: 12,
                          right: 12,
                          child: SafeArea(
                            child: Material(
                              color: StrataPalette.surface.withValues(alpha: .85),
                              borderRadius: BorderRadius.circular(10),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(10),
                                onTap: () => setState(() => _editorExpanded = !_editorExpanded),
                                child: Padding(
                                  padding: const EdgeInsets.all(8),
                                  child: Icon(
                                    _editorExpanded
                                        ? Icons.close_fullscreen_rounded
                                        : Icons.open_in_full_rounded,
                                    size: 18,
                                    color: StrataPalette.onSurfaceMuted,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _LeftNavPane extends ConsumerWidget {
  const _LeftNavPane({required this.shell});

  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final counts = ref.watch(folderNoteCountProvider).value ?? const <int?, int>{};
    final allCount = counts.values.fold<int>(0, (a, b) => a + b);
    final plannedCount = ref.watch(plannedNotesProvider).value?.length ?? 0;
    final trashCount = ref.watch(trashStreamProvider).value?.length ?? 0;

    return Container(
      color: StrataPalette.surface.withValues(alpha: .55),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const _BrandMark(showName: true),
              const SizedBox(height: 18),
              _LeftSearchField(
                onTap: () {
                  ref.read(searchToggleProvider.notifier).set(true);
                  shell.goBranch(0, initialLocation: shell.currentIndex == 0);
                },
              ),
              const SizedBox(height: 20),
              _NavRow(
                icon: Icons.sticky_note_2_outlined,
                activeIcon: Icons.sticky_note_2_rounded,
                label: 'All Notes',
                count: allCount,
                selected: shell.currentIndex == 0,
                onTap: () {
                  ref.read(selectedFolderProvider.notifier).select(null);
                  shell.goBranch(0, initialLocation: shell.currentIndex == 0);
                },
              ),
              const SizedBox(height: 4),
              _NavRow(
                icon: Icons.event_note_outlined,
                activeIcon: Icons.event_note_rounded,
                label: 'Planned',
                count: plannedCount,
                selected: shell.currentIndex == 1,
                onTap: () => shell.goBranch(1, initialLocation: shell.currentIndex == 1),
              ),
              const SizedBox(height: 4),
              _NavRow(
                icon: Icons.delete_outline_rounded,
                activeIcon: Icons.delete_rounded,
                label: 'Trash',
                count: trashCount,
                selected: shell.currentIndex == 2,
                onTap: () => shell.goBranch(2, initialLocation: shell.currentIndex == 2),
              ),
              const SizedBox(height: 18),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Folders',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.1,
                        ),
                      ),
                    ),
                    Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        color: StrataPalette.accent.withValues(alpha: .10),
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: IconButton(
                        tooltip: 'New folder',
                        visualDensity: VisualDensity.compact,
                        iconSize: 16,
                        color: StrataPalette.accent,
                        onPressed: () => promptNewFolder(context, ref),
                        icon: const Icon(Icons.add_rounded),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              Expanded(
                child: SingleChildScrollView(
                  child: FolderTree(
                    showAllNotesRow: false,
                    onPicked: (_) {
                      if (shell.currentIndex != 0) {
                        shell.goBranch(0);
                      }
                    },
                  ),
                ),
              ),
              const SizedBox(height: 8),
              _NavRow(
                icon: Icons.settings_outlined,
                activeIcon: Icons.settings_rounded,
                label: 'Settings',
                selected: shell.currentIndex == 3,
                compact: true,
                onTap: () => shell.goBranch(3, initialLocation: shell.currentIndex == 3),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LeftSearchField extends StatelessWidget {
  const _LeftSearchField({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: StrataPalette.surfaceHigh.withValues(alpha: .75),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          child: Row(
            children: [
              Icon(Icons.search_rounded, size: 18, color: StrataPalette.onSurfaceMuted),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Search notes...',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: StrataPalette.onSurfaceMuted,
                      ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavRow extends StatelessWidget {
  const _NavRow({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.selected,
    required this.onTap,
    this.count,
    this.compact = false,
  });

  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final int? count;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final color = selected ? StrataPalette.accent : StrataPalette.onSurfaceMuted;
    final fg = selected ? StrataPalette.accent : StrataPalette.onBackground;
    return Material(
      color: selected ? StrataPalette.accent.withValues(alpha: .1) : Colors.transparent,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 7),
          child: Row(
            children: [
              const SizedBox(width: 22),
              Icon(selected ? activeIcon : icon, size: 18, color: color),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    color: fg,
                  ),
                ),
              ),
              if (count != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: selected
                        ? StrataPalette.accent.withValues(alpha: .14)
                        : StrataPalette.surfaceHighest.withValues(alpha: .8),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '$count',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: selected ? StrataPalette.accent : StrataPalette.onSurfaceMuted,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MiddlePane extends ConsumerWidget {
  const _MiddlePane({required this.shell});

  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // The active branch screen renders in the middle pane.
    // HomeScreen/Planned/Trash/Settings already have their own scaffold.
    // We wrap in a ClipRect to keep it clean.
    return ClipRect(
      child: Material(
        color: StrataPalette.background.withValues(alpha: .35),
        child: shell,
      ),
    );
  }
}

class _EditorPlaceholderPane extends StatelessWidget {
  const _EditorPlaceholderPane();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.edit_note_rounded,
              size: 56,
              color: StrataPalette.onSurfaceMuted.withValues(alpha: .35),
            ),
            const SizedBox(height: 16),
            Text(
              'Select a note to view',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: StrataPalette.onSurfaceMuted,
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Choose a note from the list to open it here.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: StrataPalette.onSurfaceMuted.withValues(alpha: .8),
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

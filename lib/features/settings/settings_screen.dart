import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../app/theme/strata_palette.dart';
import '../../app/theme/text_scale.dart';
import '../../app/theme/theme_variant.dart';
import '../../core/widgets/glass_card.dart';
import '../../core/widgets/toasts.dart';
import '../../data/models/note.dart';
import '../../providers/core_providers.dart';
import '../../providers/notes_providers.dart';
import '../../data/services/sync/sync_engine.dart' show PeerInfo, SyncEngine;

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
        appBar: AppBar(titleSpacing: 16, title: const Text('Settings')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
              children: [
                _SectionCard(
                  title: 'Library',
                  icon: Icons.style_outlined,
                  children: [
                    _Tile(
                      icon: Icons.style_outlined,
                      label: 'Manage tags',
                      sub: 'Create, rename and color-code tags',
                      onTap: () => context.go('/settings/tags'),
                    ),
                  ],
                ).entrance(index: 0),
                const SizedBox(height: 14),
                const _ThemeSection(),
                const SizedBox(height: 14),
                const _TemplatesSection(),
                const SizedBox(height: 14),
                const _SyncSection(),
                const SizedBox(height: 14),
                _SectionCard(
                  title: 'Data',
                  icon: Icons.settings_backup_restore_rounded,
                  children: [
                    _Tile(
                      icon: Icons.ios_share_rounded,
                      label: 'Backup now',
                      sub: 'Export everything as a single .strata file',
                      onTap: () => _exportBackup(context, ref),
                    ),
                    const Divider(height: 1),
                    _Tile(
                      icon: Icons.restore_rounded,
                      label: 'Restore backup',
                      sub: 'Replaces current notes with a backup file',
                      onTap: () => _importBackup(context, ref),
                    ),
                  ],
                ).entrance(index: 2),
                const SizedBox(height: 14),
                _SectionCard(
                  title: 'About',
                  icon: Icons.info_outline_rounded,
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Container(
                            width: 52,
                            height: 52,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(15),
                              gradient: const LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [Color(0xFF1C1A16), Color(0xFF0A0908)],
                              ),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(9),
                              child: Image.asset(
                                'assets/icons/ic_foreground.png',
                              ),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Strata',
                                  style: TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                Text(
                                  'v1.0.0 · local-first notes',
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(
                                        color: StrataPalette.onSurfaceMuted,
                                      ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ).entrance(index: 3),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _exportBackup(BuildContext context, WidgetRef ref) async {
    try {
      final messenger = ScaffoldMessenger.of(context);
      final stamp = DateTime.now()
          .toIso8601String()
          .substring(0, 16)
          .replaceAll(RegExp(r'[:T]'), '-');
      final tmpPath =
          '${Directory.systemTemp.path}/strata-backup-$stamp.strata';
      final file = await ref.read(backupServiceProvider).exportToFile(tmpPath);
      await SharePlus.instance.share(
        ShareParams(files: [XFile(file.path)], text: 'Strata backup'),
      );
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Backup exported — choose where to save it'),
        ),
      );
    } catch (e) {
      showToast(ref, 'Backup failed: $e', type: ToastType.error);
    }
  }

  Future<void> _importBackup(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Restore backup?'),
        content: const Text(
          'This replaces ALL current notes, folders and files with the contents of the backup.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Restore'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      final files = await FilePicker.pickFiles(
        type: FileType.any,
        dialogTitle: 'Pick a .strata backup file',
      );
      final path = files.isEmpty ? null : files.first.path;
      if (path == null) return;
      final count = await ref.read(backupServiceProvider).restoreFromFile(path);
      ref.invalidate(notesInFolderProvider);
      ref.invalidate(foldersStreamProvider);
      ref.invalidate(tagsStreamProvider);
      ref.invalidate(trashStreamProvider);
      showToast(ref, 'Restored $count notes');
    } catch (e) {
      showToast(ref, 'Restore failed: $e', type: ToastType.error);
    }
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.icon,
    required this.children,
  });

  final String title;
  final IconData icon;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 6, bottom: 8),
          child: Row(
            children: [
              Icon(icon, size: 17, color: StrataPalette.accent),
              const SizedBox(width: 7),
              Text(
                title.toUpperCase(),
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: StrataPalette.onSurfaceMuted,
                ),
              ),
            ],
          ),
        ),
        GlassCard(
          borderRadius: 22,
          padding: EdgeInsets.zero,
          child: Column(children: children),
        ),
      ],
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({
    required this.icon,
    required this.label,
    required this.sub,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String sub;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Icon(icon, size: 22, color: StrataPalette.accent),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                    Text(
                      sub,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: StrataPalette.onSurfaceMuted,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: StrataPalette.onSurfaceMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TemplatesSection extends ConsumerWidget {
  const _TemplatesSection();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final templates = ref.watch(templatesStreamProvider).value ?? const [];
    return _SectionCard(
      title: 'Templates',
      icon: Icons.article_outlined,
      children: [
        if (templates.isEmpty)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'No templates yet — use "Save as template" in any note\'s menu.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: StrataPalette.onSurfaceMuted,
              ),
            ),
          )
        else
          for (final t in templates) _TemplateRow(note: t),
      ],
    );
  }
}

class _ThemeSection extends ConsumerWidget {
  const _ThemeSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(themeVariantProvider);
    return _SectionCard(
      title: 'Appearance',
      icon: Icons.palette_outlined,
      children: [
        for (final variant in ThemeVariant.values)
          _ThemeVariantTile(
            variant: variant,
            selected: variant == current,
            onTap: () =>
                ref.read(themeVariantProvider.notifier).set(variant),
          ),
        const Divider(height: 1),
        const _TextSizeTile(),
      ],
    );
  }
}

class _TextSizeTile extends ConsumerWidget {
  const _TextSizeTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textScale = ref.watch(textScaleProvider);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.text_fields_rounded,
                size: 20,
                color: StrataPalette.accent,
              ),
              const SizedBox(width: 12),
              Text(
                'Text size',
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                ),
              ),
              const Spacer(),
              Text(
                textScale.label,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: StrataPalette.onSurfaceMuted,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          SegmentedButton<TextScale>(
            segments: [
              for (final s in TextScale.values)
                ButtonSegment<TextScale>(
                  value: s,
                  label: Text(
                    switch (s) {
                      TextScale.small => 'A',
                      TextScale.normal => 'A',
                      TextScale.large => 'A',
                      TextScale.xLarge => 'A',
                    },
                    style: TextStyle(
                      fontSize: switch (s) {
                        TextScale.small => 12,
                        TextScale.normal => 14,
                        TextScale.large => 16,
                        TextScale.xLarge => 19,
                      },
                    ),
                  ),
                ),
            ],
            selected: {textScale},
            showSelectedIcon: false,
            onSelectionChanged: (sel) =>
                ref.read(textScaleProvider.notifier).set(sel.first),
            style: ButtonStyle(
              visualDensity: VisualDensity.compact,
              textStyle: const WidgetStatePropertyAll(
                TextStyle(fontWeight: FontWeight.w700),
              ),
              foregroundColor: WidgetStateProperty.resolveWith(
                (states) => states.contains(WidgetState.selected)
                    ? StrataPalette.accent
                    : StrataPalette.onSurfaceMuted,
              ),
              side: WidgetStateProperty.resolveWith(
                (states) => BorderSide(
                  color: states.contains(WidgetState.selected)
                      ? StrataPalette.accent
                      : StrataPalette.outline,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ThemeVariantTile extends StatelessWidget {
  const _ThemeVariantTile({
    required this.variant,
    required this.selected,
    required this.onTap,
  });

  final ThemeVariant variant;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = variant.palette;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              // Mini palette preview
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: selected
                        ? StrataPalette.accent
                        : StrataPalette.outline,
                    width: selected ? 2 : 1,
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(9),
                  child: Column(
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            Expanded(child: Container(color: p.background)),
                            Expanded(child: Container(color: p.surface)),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Row(
                          children: [
                            Expanded(child: Container(color: p.surfaceHigh)),
                            Expanded(
                                child: Container(color: p.surfaceHighest)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      variant.label,
                      style: TextStyle(
                        fontWeight:
                            selected ? FontWeight.w700 : FontWeight.w600,
                        fontSize: 15,
                        color: selected
                            ? StrataPalette.accent
                            : StrataPalette.onBackground,
                      ),
                    ),
                    Text(
                      variant.description,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: StrataPalette.onSurfaceMuted,
                      ),
                    ),
                  ],
                ),
              ),
              if (selected)
                const Icon(
                  Icons.check_circle_rounded,
                  size: 20,
                  color: StrataPalette.accent,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TemplateRow extends ConsumerWidget {
  const _TemplateRow({required this.note});

  final Note note;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: Row(
        children: [
          Expanded(
            child: Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(14),
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () => context.push('/editor/${note.id}'),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 13,
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.article_outlined,
                        size: 21,
                        color: StrataPalette.accent,
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(
                          note.title.trim().isEmpty
                              ? 'Untitled'
                              : note.title.trim(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          IconButton(
            tooltip: 'Delete template',
            icon: Icon(
              Icons.delete_outline_rounded,
              size: 20,
              color: StrataPalette.onSurfaceMuted,
            ),
            onPressed: () => _confirmDelete(context, ref),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete template?'),
        content: Text(
          '“${note.title.trim().isEmpty ? 'Untitled' : note.title.trim()}” will be removed permanently.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(noteActionsProvider).deleteForever(note.id);
      showToast(ref, 'Template deleted');
    }
  }
}

class _SyncSection extends ConsumerWidget {
  const _SyncSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final engine = ref.watch(syncEngineProvider);
    return ListenableBuilder(
      listenable: engine,
      builder: (context, _) => _buildBody(context, ref, engine),
    );
  }

  Widget _buildBody(BuildContext context, WidgetRef ref, SyncEngine engine) {
    final cfg = engine.config;

    return _SectionCard(
      title: 'LAN Sync',
      icon: Icons.lan_outlined,
      children: [
        SwitchListTile(
          value: cfg.enabled,
          onChanged: (v) async {
            await ref.read(syncEngineProvider).setEnabled(v);
          },
          title: const Text(
            'Discoverable on this network',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
          ),
          subtitle: Text(
            cfg.enabled
                ? 'Serving as “${cfg.deviceName}”'
                : 'Turn on to sync with other devices running Strata',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: StrataPalette.onSurfaceMuted,
            ),
          ),
          activeThumbColor: StrataPalette.accent,
        ),
        if (cfg.enabled) ...[
          Divider(height: 1, color: StrataPalette.outline),
          _Tile(
            icon: Icons.badge_outlined,
            label: 'Device name',
            sub: cfg.deviceName,
            onTap: () => _editName(context, ref, cfg.deviceName),
          ),
          SwitchListTile(
            value: cfg.autoSync,
            onChanged: (v) async {
              await ref.read(syncEngineProvider).setAutoSync(v);
            },
            title: const Text(
              'Auto-sync every 5 min',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
            ),
            activeThumbColor: StrataPalette.accent,
          ),
          Divider(height: 1, color: StrataPalette.outline),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    engine.peers.isEmpty
                        ? 'No devices found yet. Open Strata on your other '
                              'device with sync enabled.'
                        : 'Devices on this network',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: StrataPalette.onSurfaceMuted,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Sync all',
                  onPressed: engine.peers.isEmpty
                      ? null
                      : () => _syncAll(context, ref),
                  icon: Icon(
                    Icons.sync_rounded,
                    size: 20,
                    color: engine.peers.isEmpty
                        ? StrataPalette.onSurfaceMuted
                        : StrataPalette.accent,
                  ),
                ),
              ],
            ),
          ),
          for (final p in engine.peers) _PeerRow(peer: p),
        ],
      ],
    );
  }

  Future<void> _editName(
    BuildContext context,
    WidgetRef ref,
    String current,
  ) async {
    final ctrl = TextEditingController(text: current);
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Device name'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          maxLength: 32,
          decoration: const InputDecoration(hintText: 'e.g. Pixel Tablet'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (name != null) {
      await ref.read(syncEngineProvider).setDeviceName(name);
    }
  }

  Future<void> _syncAll(BuildContext context, WidgetRef ref) async {
    showToast(ref, 'Syncing…');
    final ok = await ref.read(syncEngineProvider).syncAll();
    showToast(ref, ok > 0 ? 'Sync complete' : 'No devices reachable');
  }
}

class _PeerRow extends ConsumerWidget {
  const _PeerRow({required this.peer});

  final PeerInfo peer;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final last = peer.lastSyncAt == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(peer.lastSyncAt!);
    final sub = peer.busy
        ? 'Syncing…'
        : last == null
        ? '${peer.host} — never synced'
        : '${peer.host} — last synced ${last.hour.toString().padLeft(2, '0')}:${last.minute.toString().padLeft(2, '0')}';
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: Row(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
              child: Row(
                children: [
                  Icon(
                    Icons.devices_other_rounded,
                    size: 21,
                    color: peer.busy
                        ? StrataPalette.accent
                        : StrataPalette.onSurfaceMuted,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          peer.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                          ),
                        ),
                        Text(
                          sub,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: StrataPalette.onSurfaceMuted),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          TextButton(
            onPressed: peer.busy ? null : () => _sync(context, ref),
            child: const Text('Sync'),
          ),
        ],
      ),
    );
  }

  Future<void> _sync(BuildContext context, WidgetRef ref) async {
    showToast(ref, 'Syncing with ${peer.name}…');
    final outcome = await ref.read(syncEngineProvider).syncWith(peer);
    showToast(
      ref,
      outcome.ok ? 'Synced: ${outcome.detail}' : outcome.detail,
      type: outcome.ok ? ToastType.success : ToastType.error,
    );
  }
}

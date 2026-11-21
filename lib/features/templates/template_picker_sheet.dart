import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/strata_palette.dart';
import '../../data/services/built_in_templates.dart';
import '../../providers/notes_providers.dart';

class TemplateChoice {
  const TemplateChoice({required this.title, required this.deltaJson});

  final String title;
  final String deltaJson;
}

/// Bottom sheet shown when creating a note: blank, a built-in starter or
/// one of the user's saved templates.
Future<TemplateChoice?> showTemplatePickerSheet(
  BuildContext context,
  WidgetRef ref,
) {
  return showModalBottomSheet<TemplateChoice>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    // Keep the sheet clear of the floating navigation dock.
    useSafeArea: true,
    builder: (ctx) =>
        FractionallySizedBox(heightFactor: .78, child: const _TemplatePicker()),
  );
}

class _TemplatePicker extends ConsumerWidget {
  const _TemplatePicker();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final saved = ref.watch(templatesStreamProvider).value ?? const [];

    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('New note', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 6),
            Text(
              'Start blank or pick a starting point.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: StrataPalette.onSurfaceMuted,
              ),
            ),
            const SizedBox(height: 10),
            _Row(
              icon: Icons.edit_note_rounded,
              label: 'Blank note',
              onTap: () => Navigator.of(
                context,
              ).pop(const TemplateChoice(title: '', deltaJson: '')),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 14, bottom: 4),
              child: Text(
                'BUILT-IN',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: StrataPalette.onSurfaceMuted,
                ),
              ),
            ),
            for (final t in BuiltinTemplates.all)
              _Row(
                icon: t.icon,
                label: t.name,
                onTap: () => Navigator.of(
                  context,
                ).pop(TemplateChoice(title: t.name, deltaJson: t.deltaJson)),
              ),
            Padding(
              padding: const EdgeInsets.only(top: 14, bottom: 4),
              child: Text(
                'YOUR TEMPLATES',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: StrataPalette.onSurfaceMuted,
                ),
              ),
            ),
            if (saved.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  'Nothing here yet — use “Save as template” in any note’s menu.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: StrataPalette.onSurfaceMuted,
                  ),
                ),
              )
            else
              for (final t in saved)
                _Row(
                  icon: Icons.article_outlined,
                  label: t.title.trim().isEmpty ? 'Untitled' : t.title.trim(),
                  onTap: () => Navigator.of(context).pop(
                    TemplateChoice(
                      title: t.title.trim(),
                      deltaJson: t.contentDelta,
                    ),
                  ),
                ),
          ],
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 13),
            child: Row(
              children: [
                Icon(icon, size: 21, color: StrataPalette.accent),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    label,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

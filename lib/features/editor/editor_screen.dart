import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';

import '../../app/router.dart';
import '../../app/theme/strata_palette.dart';
import '../../core/utils/due_status.dart';
import '../../core/utils/note_delta.dart';
import '../../core/utils/text_stats.dart';
import '../../core/utils/wiki_links.dart';
import '../../core/widgets/confirm_dialog.dart';
import '../../core/widgets/glass_card.dart';
import '../../core/widgets/pointer_activity.dart';

import '../../core/widgets/toasts.dart';
import '../../data/models/note.dart';
import '../../data/services/divider_embed.dart';
import '../../data/services/image_embed_builder.dart';
import '../../data/services/table_embed.dart';
import '../../data/services/table_embed_builder.dart';
import '../../providers/core_providers.dart';
import '../home/widgets/note_actions_sheet.dart';
import '../tags/assign_tags_sheet.dart';
import 'backlinks_strip.dart';
import 'wiki_suggest_panel.dart';

enum _SaveState { idle, saving, saved }

/// Custom scheme embedded in the quill link attribute so wiki links can be
/// told apart from regular URLs at tap time.
const _wikiScheme = 'strata://note/';

/// Value of quill's `background` attribute applied by the highlight toggle:
/// Strata amber at 30% opacity (#AARRGGBB), matching the search-result tint.
const _highlightValue = '#4DDEA133';

class EditorScreen extends ConsumerStatefulWidget {
  const EditorScreen({super.key, required this.noteId, this.onClose});

  final int noteId;
  final VoidCallback? onClose;

  @override
  ConsumerState<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends ConsumerState<EditorScreen> {
  Note? _note;
  QuillController? _controller;
  final _titleCtrl = TextEditingController();
  final _focusNode = FocusNode();
  final _scrollCtrl = ScrollController();
  Timer? _debounce;
  Timer? _suggestDebounce;
  Timer? _pillTimer;

  /// Transient save indicator; null hides the floating pill.
  _SaveState? _pillState;
  bool _dirty = false;
  (int, int) _counts = (0, 0);
  WikiQuery? _wikiQuery;
  List<Note> _suggestions = const [];
  bool _linkFormatting = false;

  /// Line-height multiplier applied to all paragraphs (default 1.55).
  double _lineHeight = 1.55;

  /// Extra vertical spacing (px) added above and below each paragraph.
  double _paraSpacing = 4.0;

  // ── In-note search ──────────────────────────────────────────────────
  bool _searchActive = false;
  final _searchCtrl = TextEditingController();
  final _searchFocus = FocusNode();
  List<int> _searchMatches = [];
  int _currentMatch = -1;
  StreamSubscription<List<SharedMediaFile>>? _receivingIntent;

  // ── Stuck selection-drag watchdog ──────────────────────────────────
  /// Key into quill's raw editor, used to reach its selection-drag notifier.
  final _editorKey = GlobalKey<EditorState>();
  ValueNotifier<Offset?>? _dragOffset;
  Timer? _dragWatch;

  @override
  void initState() {
    super.initState();
    _load();
    // Listen for shared images from other apps (e.g. Android share sheet).
    _receivingIntent = ReceiveSharingIntent.instance.getMediaStream().listen(
      _handleSharedMedia,
      onError: (err) => debugPrint('receive_sharing_intent error: $err'),
    );
    // Handle intent that launched the app (cold start).
    ReceiveSharingIntent.instance.getInitialMedia().then(_handleSharedMedia);
  }

  /// Blank/corrupt deltas fall back to a fresh document instead of leaving
  /// the editor stuck on its loading spinner. See [parseNoteDelta].
  Future<void> _load() async {
    final note = await ref.read(notesRepositoryProvider).getById(widget.noteId);
    if (!mounted) return;
    if (note == null) {
      Navigator.of(context).pop();
      return;
    }
    final controller = QuillController(
      document: parseNoteDelta(note.contentDelta),
      selection: const TextSelection.collapsed(offset: 0),
      config: QuillControllerConfig(
        clipboardConfig: QuillClipboardConfig(
          enableExternalRichPaste: true,
          onClipboardPaste: _onClipboardPaste,
          onImagePaste: _onImagePaste,
        ),
      ),
    );
    controller.addListener(_onDocChanged);
    setState(() {
      _note = note;
      _controller = controller;
      _titleCtrl.text = note.title;
      _counts = (note.wordCount, note.charCount);
    });
  }

  void _onDocChanged() {
    _dirty = true;
    final plain = _controller?.document.toPlainText() ?? '';
    setState(() => _counts = (TextStats.wordCount(plain), plain.length));
    _scheduleSave();
    _updateWikiSuggestions();
    unawaited(_autoLinkWikiTokens());
  }

  Future<String?> _onImagePaste(Uint8List imageBytes) async {
    final note = _note;
    if (note == null) return null;
    try {
      final name = '${DateTime.now().microsecondsSinceEpoch}_paste.png';
      final file = File('${Directory.systemTemp.path}/$name');
      await file.writeAsBytes(imageBytes, flush: true);
      final att = await ref
          .read(attachmentsRepositoryProvider)
          .importForNote(note.id, file);
      if (mounted) showToast(ref, 'Image pasted');
      return att.storedPath;
    } catch (_) {
      if (mounted) {
        showToast(ref, 'Could not paste image', type: ToastType.error);
      }
      return null;
    }
  }

  Future<bool> _onClipboardPaste() async {
    final controller = _controller;
    if (controller == null || !controller.selection.isValid) return false;

    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text;
    if (text == null || text.isEmpty) return false;
    if (!_looksLikeCode(text)) return false;

    final index = controller.selection.baseOffset;
    final length = controller.selection.extentOffset - index;
    final pasteText = text.replaceAll('\r\n', '\n');
    controller.replaceText(index, length, pasteText, null);
    controller.formatText(index, pasteText.length, Attribute.codeBlock);
    controller.updateSelection(
      TextSelection.collapsed(offset: index + pasteText.length),
      ChangeSource.local,
    );
    return true;
  }

  bool _looksLikeCode(String text) {
    final lines = text.replaceAll('\r\n', '\n').split('\n');
    if (lines.length < 2) return false;

    var score = 0;
    final codePattern = RegExp(
      r'[{};<>]=?|=>|</|/>|\b(def|class|import|from|function|const|let|var|public|private|protected|return|if|for|while|switch|case|break|continue|try|catch|finally|#include|package|void|int|string|bool|async|await|new)\b|//|/\*|\*/|#(?![0-9a-fA-F]{3,8}\b)',
    );

    for (final line in lines) {
      if (RegExp(r'^\s{2,}|\t').hasMatch(line)) score += 2;
      if (codePattern.hasMatch(line)) score += 2;
      if (RegExp(r'[{}\[\]();]').hasMatch(line)) score += 1;
    }

    final nonEmpty = lines.where((l) => l.trim().isNotEmpty).length;
    if (nonEmpty < 2) return false;
    return score >= 6;
  }

  void _updateWikiSuggestions() {
    final controller = _controller;
    if (controller == null) return;
    final caret = controller.selection.baseOffset;
    final plain = controller.document.toPlainText();
    final q = caret >= 0 ? WikiLinks.detectQuery(plain, caret) : null;

    if (q == null) {
      _suggestDebounce?.cancel();
      if (_wikiQuery != null) {
        setState(() {
          _wikiQuery = null;
          _suggestions = const [];
        });
      }
      return;
    }
    if (_wikiQuery != null &&
        _wikiQuery!.startIndex == q.startIndex &&
        _wikiQuery!.query == q.query) {
      return;
    }
    _suggestDebounce?.cancel();
    _suggestDebounce = Timer(const Duration(milliseconds: 120), () async {
      final notes = await ref
          .read(notesRepositoryProvider)
          .findSuggestions(q.query, excludeNoteId: widget.noteId);
      if (!mounted) return;
      setState(() {
        _wikiQuery = q;
        _suggestions = notes;
      });
    });
  }

  /// Gives hand-typed `[[Title]]` tokens their strata:// link attribute so
  /// they become tappable without going through the autocomplete picker.
  Future<void> _autoLinkWikiTokens() async {
    final controller = _controller;
    if (controller == null || _linkFormatting) return;
    _linkFormatting = true;
    try {
      final plain = controller.document.toPlainText();
      for (final token in WikiLinks.completeTokens(plain)) {
        final link = _linkValueAt(controller, token.start, token.length);
        if (link != null) continue;

        // Skip tokens that moved/changed while we were resolving (the user
        // kept typing): verify the same text still sits at the same offset.
        final now = controller.document.toPlainText();
        if (!now.startsWith(plain)) continue;

        final target = await ref
            .read(notesRepositoryProvider)
            .findByTitle(token.title);
        if (target == null || target.id == widget.noteId) continue;
        if (!mounted || _controller != controller) return;
        final current = controller.document.toPlainText();
        if (current.length < token.end ||
            current.substring(token.start, token.end) !=
                plain.substring(token.start, token.end)) {
          continue;
        }
        controller.formatText(
          token.start,
          token.length,
          LinkAttribute('$_wikiScheme${target.id}'),
        );
      }
    } finally {
      _linkFormatting = false;
    }
  }

  bool _handleEditorTap(
    TapUpDetails details,
    TextPosition Function(Offset offset) positionFor,
  ) {
    final controller = _controller;
    if (controller == null) return false;
    final docIndex = positionFor(details.localPosition).offset;
    final plain = controller.document.toPlainText();
    if (docIndex <= 0 || docIndex > plain.length) return false;

    WikiToken? hit;
    for (final t in WikiLinks.completeTokens(plain)) {
      if (docIndex >= t.start && docIndex <= t.end) {
        hit = t;
        break;
      }
    }
    final token = hit;
    if (token == null) return false;

    final link = _linkValueAt(controller, token.start, token.length);
    if (link == null || !link.startsWith(_wikiScheme)) return false;
    final id = int.tryParse(link.substring(_wikiScheme.length));
    if (id == null || id == widget.noteId) return false;

    unawaited(context.push('/editor/$id'));
    return true; // consume: don't move the caret / show toolbar
  }

  /// Returns the link attribute value covering [index, index + length),
  /// merging styles across all segments of the range.
  String? _linkValueAt(QuillController controller, int index, int length) {
    for (final style in controller.document.collectAllStyles(index, length)) {
      final v = style.attributes[Attribute.link.key]?.value;
      if (v is String) return v;
    }
    return null;
  }

  Future<void> _insertWikiSuggestion(Note target) async {
    final controller = _controller;
    final q = _wikiQuery;
    if (controller == null || q == null) return;
    final title = target.title.trim().isEmpty
        ? 'Untitled'
        : target.title.trim();
    final replacement = '$title]] ';
    final replaceStart = q.startIndex + 2;
    final replaceLen = (controller.selection.baseOffset - replaceStart).clamp(
      0,
      controller.document.length,
    );

    _linkFormatting = true;
    controller.replaceText(
      replaceStart,
      replaceLen,
      replacement,
      TextSelection.collapsed(offset: replaceStart + replacement.length),
    );
    controller.formatText(
      q.startIndex,
      title.length + 4,
      LinkAttribute('$_wikiScheme${target.id}'),
    );
    _linkFormatting = false;

    _focusNode.requestFocus();
    setState(() {
      _wikiQuery = null;
      _suggestions = const [];
    });
  }

  void _onTitleChanged(String value) {
    _dirty = true;
    _scheduleSave();
  }

  void _scheduleSave() {
    _debounce?.cancel();
    _pillTimer?.cancel();
    if (_pillState != _SaveState.saving) {
      setState(() => _pillState = _SaveState.saving);
    }
    _debounce = Timer(const Duration(milliseconds: 900), _flushSave);
  }

  Future<void> _flushSave() async {
    final note = _note;
    final controller = _controller;
    if (!_dirty || note == null || controller == null) return;
    _dirty = false;
    await ref
        .read(noteActionsProvider)
        .saveContent(
          note,
          jsonEncode(controller.document.toDelta().toJson()),
          title: _titleCtrl.text,
        );
    if (mounted) {
      setState(() => _pillState = _SaveState.saved);
      // The pill overlaps content, so it disappears again after a moment.
      _pillTimer?.cancel();
      _pillTimer = Timer(const Duration(milliseconds: 2200), () {
        if (mounted) setState(() => _pillState = null);
      });
    }
  }

  Future<void> _insertImage() async {
    final note = _note;
    final controller = _controller;
    if (note == null || controller == null) return;
    final files = await FilePicker.pickFiles(type: FileType.image);
    final path = files.isEmpty ? null : files.first.path;
    if (path == null) return;
    try {
      final att = await ref
          .read(attachmentsRepositoryProvider)
          .importForNote(note.id, File(path));
      final index = controller.selection.baseOffset.clamp(
        0,
        controller.document.length,
      );
      controller.replaceText(
        index,
        0,
        BlockEmbed('image', att.storedPath),
        null,
      );
      showToast(ref, 'Image inserted');
    } catch (e) {
      showToast(ref, 'Could not insert image', type: ToastType.error);
    }
  }

  Future<void> _insertTable() async {
    final controller = _controller;
    if (controller == null) return;
    final index = controller.selection.baseOffset.clamp(
      0,
      controller.document.length,
    );
    controller.replaceText(
      index,
      0,
      StrataTableEmbed.fromCells([
        ['', ''],
        ['', ''],
      ]),
      null,
    );
    // Ensure there's a paragraph after the table so the cursor can escape.
    final after = controller.selection.baseOffset;
    if (after >= controller.document.length - 1) {
      controller.replaceText(after, 0, '\n', null);
    }
    controller.updateSelection(
      TextSelection.collapsed(offset: controller.selection.baseOffset),
      ChangeSource.local,
    );
  }

  // ── In-note search ──────────────────────────────────────────────────

  void _toggleSearch() {
    setState(() {
      _searchActive = !_searchActive;
      if (!_searchActive) {
        _searchCtrl.clear();
        _searchMatches = [];
        _currentMatch = -1;
      }
    });
    if (_searchActive) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _searchFocus.requestFocus();
      });
    }
  }

  void _findMatches() {
    final query = _searchCtrl.text;
    final controller = _controller;
    if (query.isEmpty || controller == null) {
      setState(() {
        _searchMatches = [];
        _currentMatch = -1;
      });
      return;
    }
    final plain = controller.document.toPlainText();
    final lower = plain.toLowerCase();
    final queryLower = query.toLowerCase();
    final matches = <int>[];
    var idx = 0;
    while (true) {
      final found = lower.indexOf(queryLower, idx);
      if (found == -1) break;
      matches.add(found);
      idx = found + 1;
    }
    setState(() {
      _searchMatches = matches;
      _currentMatch = matches.isEmpty ? -1 : 0;
    });
    if (_currentMatch >= 0) _jumpToMatch(_currentMatch);
  }

  void _nextMatch() {
    if (_searchMatches.isEmpty) return;
    setState(() {
      _currentMatch = (_currentMatch + 1) % _searchMatches.length;
    });
    _jumpToMatch(_currentMatch);
  }

  void _prevMatch() {
    if (_searchMatches.isEmpty) return;
    setState(() {
      _currentMatch =
          (_currentMatch - 1 + _searchMatches.length) % _searchMatches.length;
    });
    _jumpToMatch(_currentMatch);
  }

  void _jumpToMatch(int index) {
    final controller = _controller;
    if (controller == null || index < 0 || index >= _searchMatches.length) {
      return;
    }
    final offset = _searchMatches[index];
    final queryLen = _searchCtrl.text.length;
    controller.updateSelection(
      TextSelection(baseOffset: offset, extentOffset: offset + queryLen),
      ChangeSource.local,
    );
  }

  Widget _buildSearchBar() {
    final count = _searchMatches.length;
    final current = _currentMatch + 1;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _searchCtrl,
              focusNode: _searchFocus,
              onChanged: (_) => _findMatches(),
              onSubmitted: (_) => _nextMatch(),
              style: const TextStyle(fontSize: 13),
              decoration: InputDecoration(
                hintText: 'Search…',
                hintStyle: const TextStyle(fontSize: 13),
                prefixIcon: const Icon(Icons.search_rounded, size: 16),
                prefixIconConstraints: const BoxConstraints(
                  minWidth: 32,
                  minHeight: 0,
                ),
                suffixIcon: _searchCtrl.text.isNotEmpty
                    ? GestureDetector(
                        onTap: () {
                          _searchCtrl.clear();
                          _findMatches();
                        },
                        child: const Icon(Icons.close_rounded, size: 14),
                      )
                    : null,
                suffixIconConstraints: const BoxConstraints(
                  minWidth: 28,
                  minHeight: 0,
                ),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 6,
                ),
                filled: true,
                fillColor: StrataPalette.surfaceHigh.withValues(alpha: .7),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(
                    color: StrataPalette.accent,
                    width: 1.2,
                  ),
                ),
              ),
            ),
          ),
          if (count > 0) ...[
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                color: StrataPalette.accent.withValues(alpha: .14),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                '$current/$count',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: StrataPalette.accent,
                ),
              ),
            ),
          ] else if (_searchCtrl.text.isNotEmpty) ...[
            const SizedBox(width: 6),
            Text(
              '0',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: StrataPalette.onSurfaceMuted,
              ),
            ),
          ],
          const SizedBox(width: 2),
          _SearchBtn(
            icon: Icons.keyboard_arrow_up_rounded,
            enabled: count > 0,
            onTap: _prevMatch,
          ),
          _SearchBtn(
            icon: Icons.keyboard_arrow_down_rounded,
            enabled: count > 0,
            onTap: _nextMatch,
          ),
          _SearchBtn(
            icon: Icons.close_rounded,
            enabled: true,
            onTap: _toggleSearch,
          ),
        ],
      ),
    );
  }

  /// Inserts a page-break divider on its own line at the caret.
  void _insertDivider() {
    final controller = _controller;
    if (controller == null) return;
    var index = controller.selection.baseOffset.clamp(
      0,
      controller.document.length,
    );
    final plain = controller.document.toPlainText();
    if (index > 0 && plain.substring(index - 1, index) != '\n') {
      controller.replaceText(index, 0, '\n', null);
      index++;
    }
    controller.replaceText(
      index,
      0,
      StrataDividerEmbed(),
      TextSelection.collapsed(offset: index + 1),
    );
    final after = controller.document.toPlainText();
    if (index + 1 >= after.length || after[index + 1] != '\n') {
      controller.replaceText(index + 1, 0, '\n', null);
    }
    _focusNode.requestFocus();
  }

  Future<void> _attachFile() async {
    final note = _note;
    if (note == null) return;
    final files = await FilePicker.pickFiles();
    if (files.isEmpty) return;
    final file = files.first;
    final path = file.path;
    if (path == null) return;
    try {
      await ref
          .read(attachmentsRepositoryProvider)
          .importForNote(note.id, File(path));
      if (mounted) {
        showToast(ref, 'Attached ${file.name}');
      }
    } catch (_) {
      if (mounted) {
        showToast(ref, 'Attachment failed', type: ToastType.error);
      }
    }
  }

  Future<void> _editReminder() async {
    final note = _note;
    if (note == null) return;
    final current = note.dueDate;

    if (current != null) {
      final action = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Reminder'),
          content: Text('This note is due ${DueStatusX.labelFor(current)}.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, 'remove'),
              child: Text(
                'Remove',
                style: TextStyle(color: StrataPalette.coral),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, 'change'),
              child: const Text('Change'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, 'keep'),
              child: const Text('Done'),
            ),
          ],
        ),
      );
      if (!mounted || action == null || action == 'keep') return;
      if (action == 'remove') {
        await _applyDueDate(note, null);
        return;
      }
    }

    final now = DateTime.now();
    final defaultDue = current ?? now.add(const Duration(hours: 1));
    final date = await showDatePicker(
      context: context,
      initialDate: defaultDue,
      firstDate: now.subtract(const Duration(days: 1)),
      lastDate: now.add(const Duration(days: 365 * 3)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(defaultDue),
    );
    if (time == null || !mounted) return;
    await _applyDueDate(
      note,
      DateTime(date.year, date.month, date.day, time.hour, time.minute),
    );
  }

  Future<void> _applyDueDate(Note note, DateTime? due) async {
    setState(() => note.dueDate = due);
    await ref.read(notesRepositoryProvider).save(note);
    final reminders = ref.read(remindersProvider);
    if (due == null) {
      await reminders.cancel(note.id);
      if (mounted) showToast(ref, 'Reminder cleared');
    } else {
      await reminders.scheduleFor(note, askPermissions: true);
      if (mounted) {
        showToast(ref, 'Reminder · ${DueStatusX.labelFor(due)}');
      }
    }
  }

  /// Quill clears its selection-drag offset only from gesture-end callbacks,
  /// so a cancelled gesture (notification shade, incoming call, app switch
  /// mid-drag) leaves it dangling — the magnifier then stays on screen
  /// forever and the copy/paste menu is replaced by an empty box.
  ///
  /// Re-attach on every build because changing the editor key recreates the
  /// raw editor along with its notifier.
  void _watchDragOffset() {
    final notifier = _editorKey.currentState?.widget.dragOffsetNotifier;
    if (notifier == null || identical(notifier, _dragOffset)) return;
    _dragOffset?.removeListener(_onDragOffsetChanged);
    _dragOffset = notifier;
    notifier.addListener(_onDragOffsetChanged);
    if (notifier.value != null) _onDragOffsetChanged();
  }

  void _onDragOffsetChanged() {
    final notifier = _dragOffset;
    if (notifier == null) return;
    _dragWatch?.cancel();
    if (notifier.value == null) return;
    _dragWatch = Timer(const Duration(milliseconds: 1000), _clearStuckDrag);
  }

  /// Clears the drag offset once no pointer is down anywhere in the app, so
  /// a drag that is still in progress is never interrupted.
  void _clearStuckDrag() {
    final notifier = _dragOffset;
    if (!mounted || notifier == null || notifier.value == null) return;
    if (PointerActivity.activePointers == 0) {
      notifier.value = null;
    } else {
      _dragWatch = Timer(const Duration(milliseconds: 1000), _clearStuckDrag);
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _suggestDebounce?.cancel();
    _pillTimer?.cancel();
    _dragWatch?.cancel();
    _dragOffset?.removeListener(_onDragOffsetChanged);
    _receivingIntent?.cancel();
    _flushSave();
    _controller?.removeListener(_onDocChanged);
    _controller?.dispose();
    _titleCtrl.dispose();
    _focusNode.dispose();
    _scrollCtrl.dispose();
    _searchCtrl.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _watchDragOffset();
    });
    final isMobile = MediaQuery.sizeOf(context).width < 640;
    final controller = _controller;
    if (controller == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final storage = ref.watch(storageProvider);
    final embeds = [
      StrataImageEmbedBuilder(
        storage: storage,
        onOpenImage: (ctx, file) => _openImageViewer(ctx, file),
      ),
      const TableEmbedBuilder(),
      const StrataDividerEmbedBuilder(),
    ];

    return PopScope(
      canPop: widget.onClose == null,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) {
          await _flushSave();
          return;
        }
        if (widget.onClose != null) {
          await _flushSave();
          if (context.mounted) widget.onClose!();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          toolbarHeight: 56,
          titleSpacing: 0,
          leading: const SizedBox.shrink(),
          leadingWidth: 8,
          title: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(width: 4),
              _EditorIconButton(
                icon: Icons.arrow_back_ios_new_rounded,
                onTap: () async {
                  await _flushSave();
                  if (!context.mounted) return;
                  if (widget.onClose != null) {
                    widget.onClose!();
                  } else {
                    Navigator.of(context).pop();
                  }
                },
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Hero(
                  tag: 'note-title-${widget.noteId}',
                  child: ValueListenableBuilder<TextEditingValue>(
                    valueListenable: _titleCtrl,
                    builder: (context, value, _) {
                      final len = value.text.trim().length;
                      final baseFont = isMobile ? 17.0 : 15.5;
                      final shrinkStart = isMobile ? 18 : 20;
                      final fontSize =
                          (baseFont -
                                  (len > shrinkStart
                                      ? (len - shrinkStart) *
                                            (isMobile ? .10 : .14)
                                      : 0))
                              .clamp(isMobile ? 14.0 : 12.5, baseFont);
                      return SizedBox(
                        height: isMobile ? 44 : 40,
                        child: TextField(
                          controller: _titleCtrl,
                          onChanged: _onTitleChanged,
                          maxLines: 1,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(
                                fontWeight: FontWeight.w600,
                                fontSize: fontSize,
                              ),
                          decoration: InputDecoration(
                            hintText: 'Untitled',
                            hintStyle: TextStyle(
                              fontSize: fontSize,
                              fontWeight: FontWeight.w500,
                              color: StrataPalette.onSurfaceDim,
                            ),
                            filled: true,
                            fillColor: StrataPalette.surfaceHighest.withValues(
                              alpha: .35,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(
                                isMobile ? 10 : 8,
                              ),
                              borderSide: BorderSide.none,
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(
                                isMobile ? 10 : 8,
                              ),
                              borderSide: BorderSide.none,
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(
                                isMobile ? 10 : 8,
                              ),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: isMobile ? 12 : 10,
                              vertical: isMobile ? 10 : 8,
                            ),
                            isDense: !isMobile,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(width: 12),
              _EditorIconButton(
                icon: Icons.search_rounded,
                isActive: _searchActive,
                onTap: _toggleSearch,
              ),
              const SizedBox(width: 4),
              _EditorIconButton(
                icon: Icons.more_vert_rounded,
                onTap: () => _showActionsMenu(context, controller),
              ),
              const SizedBox(width: 8),
            ],
          ),
        ),
        body: Column(
          children: [
            if (_searchActive)
              AnimatedSize(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOutCubic,
                child: _buildSearchBar(),
              ),
            _Toolbar(
              onInsertImage: _insertImage,
              onInsertTable: _insertTable,
              onInsertDivider: _insertDivider,
              onAttachFile: _attachFile,
              onEditReminder: _editReminder,
              dueDate: _note?.dueDate,
            ),
            Divider(height: 1, color: StrataPalette.outline),
            Expanded(
              child: Stack(
                children: [
                  Align(
                    alignment: Alignment.topCenter,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 860),
                      child: QuillEditor.basic(
                        key: ValueKey('editor-$_lineHeight-$_paraSpacing'),
                        controller: controller,
                        focusNode: _focusNode,
                        scrollController: _scrollCtrl,
                        config: QuillEditorConfig(
                          editorKey: _editorKey,
                          placeholder: 'Start writing…',
                          padding: const EdgeInsets.fromLTRB(16, 6, 16, 100),
                          embedBuilders: embeds,
                          onTapUp: _handleEditorTap,
                          quillMagnifierBuilder: defaultQuillMagnifierBuilder,
                          customStyles: DefaultStyles(
                            h1: DefaultTextBlockStyle(
                              Theme.of(context).textTheme.headlineMedium!,
                              const HorizontalSpacing(0, 0),
                              VerticalSpacing(
                                _paraSpacing + 10,
                                _paraSpacing + 2,
                              ),
                              const VerticalSpacing(0, 0),
                              null,
                            ),
                            h2: DefaultTextBlockStyle(
                              Theme.of(context).textTheme.headlineSmall!
                                  .copyWith(fontWeight: FontWeight.w700),
                              const HorizontalSpacing(0, 0),
                              VerticalSpacing(
                                _paraSpacing + 8,
                                _paraSpacing + 1,
                              ),
                              const VerticalSpacing(0, 0),
                              null,
                            ),
                            h3: DefaultTextBlockStyle(
                              Theme.of(context).textTheme.titleLarge!.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                              const HorizontalSpacing(0, 0),
                              VerticalSpacing(_paraSpacing + 6, _paraSpacing),
                              const VerticalSpacing(0, 0),
                              null,
                            ),
                            paragraph: DefaultTextBlockStyle(
                              Theme.of(context).textTheme.bodyLarge!.copyWith(
                                height: _lineHeight,
                              ),
                              const HorizontalSpacing(0, 0),
                              VerticalSpacing(_paraSpacing, _paraSpacing),
                              const VerticalSpacing(0, 0),
                              null,
                            ),
                            lists: DefaultListBlockStyle(
                              Theme.of(context).textTheme.bodyLarge!.copyWith(
                                height: _lineHeight,
                              ),
                              const HorizontalSpacing(0, 0),
                              VerticalSpacing(_paraSpacing, _paraSpacing),
                              const VerticalSpacing(0, 0),
                              null,
                              null,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (_pillState != null)
                    Positioned(
                      top: 4,
                      right: 14,
                      child: IgnorePointer(
                        child: _SavePill(state: _pillState!),
                      ),
                    ),
                  if (_wikiQuery != null)
                    Positioned(
                      left: 12,
                      right: 12,
                      bottom: 10,
                      child: WikiSuggestPanel(
                        suggestions: _suggestions,
                        onPicked: _insertWikiSuggestion,
                      ),
                    ),
                ],
              ),
            ),
            BacklinksStrip(noteId: widget.noteId),
            Container(
              decoration: BoxDecoration(
                color: Theme.of(
                  context,
                ).scaffoldBackgroundColor.withValues(alpha: .92),
                border: Border(top: BorderSide(color: StrataPalette.outline)),
              ),
              child: SafeArea(
                top: false,
                child: Row(
                  children: [
                    Expanded(
                      child: _FormatBar(
                        controller: controller,
                        onInsertDivider: _insertDivider,
                        lineHeight: _lineHeight,
                        paraSpacing: _paraSpacing,
                        onLineHeightChanged: (v) =>
                            setState(() => _lineHeight = v),
                        onParaSpacingChanged: (v) =>
                            setState(() => _paraSpacing = v),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(2, 4, 10, 4),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 1,
                            height: 20,
                            margin: const EdgeInsets.only(right: 10),
                            color: StrataPalette.outlineStrong,
                          ),
                          _StatBlock(value: '${_counts.$1}', label: 'words'),
                          const SizedBox(width: 10),
                          _StatBlock(value: '${_counts.$2}', label: 'chars'),
                          const SizedBox(width: 6),
                          Container(
                            width: 1,
                            height: 20,
                            margin: const EdgeInsets.only(right: 6),
                            color: StrataPalette.outlineStrong,
                          ),
                          _UndoRedoBtn(
                            icon: Icons.undo_rounded,
                            enabled: controller.hasUndo,
                            onTap: () => controller.undo(),
                          ),
                          const SizedBox(width: 2),
                          _UndoRedoBtn(
                            icon: Icons.redo_rounded,
                            enabled: controller.hasRedo,
                            onTap: () => controller.redo(),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openImageViewer(BuildContext ctx, File file) {
    ctx.push(
      '/viewer',
      extra: AttachmentViewArgs(path: file.path, name: 'Image'),
    );
  }

  /// Handles images shared to Strata via the Android share sheet.
  void _handleSharedMedia(List<SharedMediaFile> files) {
    for (final f in files) {
      _importExternalImage(File(f.path));
    }
  }

  /// Imports an image from an external source (drag-and-drop or share intent)
  /// and inserts it at the current caret position.
  Future<void> _importExternalImage(File file) async {
    final note = _note;
    final controller = _controller;
    if (note == null || controller == null) return;
    try {
      final att = await ref
          .read(attachmentsRepositoryProvider)
          .importForNote(note.id, file);
      final index = controller.selection.baseOffset.clamp(
        0,
        controller.document.length,
      );
      controller.replaceText(
        index,
        0,
        BlockEmbed('image', att.storedPath),
        null,
      );
      if (mounted) showToast(ref, 'Image inserted');
    } catch (e) {
      if (mounted) {
        showToast(ref, 'Could not import image', type: ToastType.error);
      }
    }
  }

  void _showActionsMenu(BuildContext context, QuillController controller) {
    final note = _note;
    if (note == null) return;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        decoration: BoxDecoration(
          color: StrataPalette.surfaceHigh,
          borderRadius: BorderRadius.circular(16),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                decoration: BoxDecoration(
                  color: StrataPalette.outlineStrong,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              _MenuTile(
                icon: Icons.undo_rounded,
                label: 'Undo',
                enabled: controller.hasUndo,
                onTap: () {
                  Navigator.pop(ctx);
                  _menuAction('undo');
                },
              ),
              _MenuTile(
                icon: Icons.redo_rounded,
                label: 'Redo',
                enabled: controller.hasRedo,
                onTap: () {
                  Navigator.pop(ctx);
                  _menuAction('redo');
                },
              ),
              _MenuTile(
                icon: Icons.content_paste_go_rounded,
                label: 'Paste as plain text',
                onTap: () {
                  Navigator.pop(ctx);
                  _menuAction('paste_plain');
                },
              ),
              Divider(height: 1, color: StrataPalette.outline),
              _MenuTile(
                icon: Icons.sell_outlined,
                label: 'Tags',
                onTap: () {
                  Navigator.pop(ctx);
                  _menuAction('tags');
                },
              ),
              _MenuTile(
                icon: Icons.folder_open_rounded,
                label: 'Move to folder',
                onTap: () {
                  Navigator.pop(ctx);
                  _menuAction('move');
                },
              ),
              _MenuTile(
                icon: Icons.analytics_outlined,
                label: 'Word count',
                onTap: () {
                  Navigator.pop(ctx);
                  _menuAction('count');
                },
              ),
              Divider(height: 1, color: StrataPalette.outline),
              _MenuTile(
                icon: Icons.picture_as_pdf_outlined,
                label: 'Export as PDF',
                onTap: () {
                  Navigator.pop(ctx);
                  _menuAction('pdf');
                },
              ),
              _MenuTile(
                icon: Icons.data_object_rounded,
                label: 'Export as Markdown',
                onTap: () {
                  Navigator.pop(ctx);
                  _menuAction('md');
                },
              ),
              _MenuTile(
                icon: Icons.article_outlined,
                label: 'Export as Word',
                onTap: () {
                  Navigator.pop(ctx);
                  _menuAction('docx');
                },
              ),
              Divider(height: 1, color: StrataPalette.outline),
              _MenuTile(
                icon: Icons.bookmark_add_outlined,
                label: 'Save as template',
                onTap: () {
                  Navigator.pop(ctx);
                  _menuAction('template');
                },
              ),
              _MenuTile(
                icon: Icons.delete_outline_rounded,
                label: 'Delete note',
                danger: true,
                onTap: () {
                  Navigator.pop(ctx);
                  _menuAction('trash');
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _menuAction(String value) async {
    final note = _note;
    if (note == null) return;
    switch (value) {
      case 'undo':
        if (_controller?.hasUndo ?? false) _controller!.undo();
      case 'redo':
        if (_controller?.hasRedo ?? false) _controller!.redo();
      case 'paste_plain':
        final ctrl = _controller;
        if (ctrl == null || !ctrl.selection.isValid) return;
        final data = await Clipboard.getData(Clipboard.kTextPlain);
        final text = data?.text;
        if (text == null || text.isEmpty) return;
        final index = ctrl.selection.baseOffset;
        final length = ctrl.selection.extentOffset - index;
        final plain = text.replaceAll('\r\n', '\n');
        ctrl.replaceText(index, length, plain, null);
        ctrl.updateSelection(
          TextSelection.collapsed(offset: index + plain.length),
          ChangeSource.local,
        );
      case 'tags':
        showAssignTagsSheet(context, note.id);
      case 'move':
        await pickFolderAndMove(context, ref, note);
        setState(() {});
      case 'count':
        await showDialog<void>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Document stats'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _statRow('Words', '${_counts.$1}'),
                _statRow('Characters', '${_counts.$2}'),
                _statRow(
                  'Reading time',
                  _counts.$1 < 200 ? '< 1 min' : '${_counts.$1 ~/ 200} min',
                ),
              ],
            ),
            actions: [
              FilledButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Done'),
              ),
            ],
          ),
        );
      case 'pdf':
        await exportPdf(
          context,
          ref,
          note.id,
          lineHeight: _lineHeight,
          paraSpacing: _paraSpacing,
        );
      case 'md':
        await exportMarkdown(context, ref, note.id);
      case 'docx':
        await exportDocx(
          context,
          ref,
          note.id,
          lineHeight: _lineHeight,
          paraSpacing: _paraSpacing,
        );
      case 'template':
        await _flushSave();
        final fresh = await ref.read(notesRepositoryProvider).getById(note.id);
        if (fresh != null) {
          await ref.read(noteActionsProvider).saveAsTemplate(fresh);
          if (mounted) showToast(ref, 'Saved as template');
        }
      case 'trash':
        final title = note.title.trim().isEmpty
            ? 'Untitled'
            : note.title.trim();
        final confirmed = await showConfirmDialog(
          context,
          title: 'Move to trash?',
          message:
              '“$title” will be moved to the trash. You can restore it '
              'anytime from the Trash tab.',
          confirmLabel: 'Move to trash',
          icon: Icons.delete_outline_rounded,
        );
        if (!confirmed) return;
        if (!mounted) return;
        final navigator = Navigator.of(context);
        await ref.read(noteActionsProvider).trash(note.id);
        if (mounted) {
          showToast(ref, 'Moved to trash');
          navigator.pop();
        }
    }
  }

  Widget _statRow(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
      ],
    ),
  );
}

class _EditorIconButton extends StatelessWidget {
  const _EditorIconButton({
    required this.icon,
    required this.onTap,
    this.isActive = false,
  });

  final IconData icon;
  final VoidCallback onTap;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: isActive
              ? StrataPalette.accent.withValues(alpha: .12)
              : StrataPalette.surfaceHighest.withValues(alpha: .6),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(
          icon,
          size: 19,
          color: isActive ? StrataPalette.accent : StrataPalette.onSurfaceMuted,
        ),
      ),
    );
  }
}

class _MenuTile extends StatelessWidget {
  const _MenuTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.enabled = true,
    this.danger = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool enabled;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final color = danger
        ? StrataPalette.coral
        : enabled
        ? StrataPalette.onBackground
        : StrataPalette.onSurfaceMuted;
    return InkWell(
      onTap: enabled ? onTap : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        child: Row(
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: color,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Floating save indicator shown briefly while/after a note saves.
class _SavePill extends StatelessWidget {
  const _SavePill({required this.state});

  final _SaveState state;

  @override
  Widget build(BuildContext context) {
    final (icon, label, color) = switch (state) {
      _SaveState.saving => (Icons.sync_rounded, 'Saving', StrataPalette.amber),
      _SaveState.saved => (
        Icons.check_circle_outline_rounded,
        'Saved',
        StrataPalette.mint,
      ),
      _SaveState.idle => (Icons.circle_outlined, '', Colors.transparent),
    };
    return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            color: Theme.of(
              context,
            ).scaffoldBackgroundColor.withValues(alpha: .85),
            border: Border.all(color: color.withValues(alpha: .35)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 13, color: color),
              const SizedBox(width: 5),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ],
          ),
        )
        .animate(key: ValueKey(state))
        .fadeIn(duration: 160.ms)
        .slideY(
          begin: -.4,
          end: 0,
          duration: 200.ms,
          curve: Curves.easeOutCubic,
        );
  }
}

class _Toolbar extends StatelessWidget {
  const _Toolbar({
    required this.onInsertImage,
    required this.onInsertTable,
    required this.onInsertDivider,
    required this.onAttachFile,
    required this.onEditReminder,
    this.dueDate,
  });

  final VoidCallback onInsertImage;
  final VoidCallback onInsertTable;
  final VoidCallback onInsertDivider;
  final VoidCallback onAttachFile;
  final VoidCallback onEditReminder;
  final DateTime? dueDate;

  @override
  Widget build(BuildContext context) {
    Widget chip(
      IconData icon,
      String label,
      VoidCallback onTap, {
      Color? iconColor,
    }) =>
        _ToolChip(icon: icon, label: label, onTap: onTap, iconColor: iconColor);

    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 4, 10, 6),
      child: _EdgeFadeStrip(
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const ClampingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              chip(Icons.table_chart_outlined, 'Table', onInsertTable),
              const SizedBox(width: 6),
              chip(Icons.image_outlined, 'Image', onInsertImage),
              const SizedBox(width: 6),
              chip(Icons.horizontal_rule_rounded, 'Break', onInsertDivider),
              const SizedBox(width: 6),
              chip(Icons.attach_file_rounded, 'Attach', onAttachFile),
              const SizedBox(width: 6),
              if (dueDate != null)
                chip(
                  Icons.notifications_active_rounded,
                  DueStatusX.labelFor(dueDate!),
                  onEditReminder,
                  iconColor: StrataPalette.amber,
                )
              else
                chip(
                  Icons.notifications_none_rounded,
                  'Remind',
                  onEditReminder,
                ),
            ],
          ),
        ),
      ),
    ).entrance(index: 0);
  }
}

/// Fades the strip's outer ~4% so clipped content hints at more off-screen.
class _EdgeFadeStrip extends StatelessWidget {
  const _EdgeFadeStrip({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      blendMode: BlendMode.dstIn,
      shaderCallback: (bounds) => const LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: [
          Colors.transparent,
          Colors.white,
          Colors.white,
          Colors.transparent,
        ],
        stops: [0, .015, .985, 1],
      ).createShader(bounds),
      child: child,
    );
  }
}

class _ToolChip extends StatefulWidget {
  const _ToolChip({
    required this.icon,
    required this.label,
    required this.onTap,
    this.iconColor,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? iconColor;

  @override
  State<_ToolChip> createState() => _ToolChipState();
}

class _ToolChipState extends State<_ToolChip> {
  double _scale = 1.0;

  void _onTapDown(_) => setState(() => _scale = 0.92);
  void _onTapUp(_) => setState(() => _scale = 1.0);
  void _onTapCancel() => setState(() => _scale = 1.0);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      child: AnimatedScale(
        scale: _scale,
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeOutCubic,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: StrataPalette.surfaceHigh.withValues(alpha: .8),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: StrataPalette.accent.withValues(alpha: .15),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                widget.icon,
                size: 14,
                color: widget.iconColor ?? StrataPalette.accent,
              ),
              const SizedBox(width: 5),
              Text(
                widget.label,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: StrataPalette.onBackground,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Hand-rolled formatting bar wired directly to the quill controller.
///
/// Replaces [QuillSimpleToolbar] so every button has a consistent size,
/// active-state highlight and predictable behavior across platforms.
class _FormatBar extends StatefulWidget {
  const _FormatBar({
    required this.controller,
    required this.onInsertDivider,
    required this.lineHeight,
    required this.paraSpacing,
    required this.onLineHeightChanged,
    required this.onParaSpacingChanged,
  });

  final QuillController controller;
  final VoidCallback onInsertDivider;
  final double lineHeight;
  final double paraSpacing;
  final ValueChanged<double> onLineHeightChanged;
  final ValueChanged<double> onParaSpacingChanged;

  @override
  State<_FormatBar> createState() => _FormatBarState();
}

class _FormatBarState extends State<_FormatBar> {
  /// All quill list flavors share the single 'list' attribute key; only the
  /// value ('bullet' | 'ordered' | 'checked' | 'unchecked') differs.
  String? get _listValue => _styleAttrs[Attribute.ul.key]?.value as String?;

  Map<String, Attribute> _styleAttrs = const {};

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_refresh);
    _readStyle();
  }

  @override
  void didUpdateWidget(covariant _FormatBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_refresh);
      widget.controller.addListener(_refresh);
      _readStyle();
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_refresh);
    super.dispose();
  }

  void _refresh() {
    if (!mounted) return;
    _readStyle();
    setState(() {});
  }

  void _readStyle() {
    try {
      _styleAttrs = widget.controller.getSelectionStyle().attributes;
    } catch (_) {
      _styleAttrs = const {};
    }
  }

  bool _has(Attribute attr) => _styleAttrs.containsKey(attr.key);

  void _toggle(Attribute attr) {
    widget.controller.formatSelection(
      _has(attr) ? Attribute.clone(attr, null) : attr,
    );
  }

  /// Adds an amber background to the selection, or strips it when the
  /// selection is already highlighted.
  void _toggleHighlight() {
    widget.controller.formatSelection(
      _has(Attribute.background)
          ? Attribute.clone(Attribute.background, null)
          : const BackgroundAttribute(_highlightValue),
    );
  }

  void _setHeader(int level) {
    final current = _styleAttrs[Attribute.header.key]?.value;
    final attr = switch (level) {
      1 => Attribute.h1,
      2 => Attribute.h2,
      _ => Attribute.h3,
    };
    widget.controller.formatSelection(
      current == level ? Attribute.header : attr,
    );
  }

  void _toggleList(Attribute target) {
    final controller = widget.controller;
    final wasActive = _listValue == target.value;
    if (_styleAttrs.containsKey(Attribute.ul.key)) {
      controller.formatSelection(Attribute.clone(Attribute.ul, null));
    }
    if (!wasActive) controller.formatSelection(target);
  }

  void _setAlign(String value) {
    if (_styleAttrs[Attribute.align.key]?.value == value) return;
    final attr = switch (value) {
      'center' => Attribute.centerAlignment,
      'right' => Attribute.rightAlignment,
      'justify' => Attribute.justifyAlignment,
      _ => Attribute.leftAlignment,
    };
    widget.controller.formatSelection(attr);
  }

  Future<void> _editLink() async {
    final selection = widget.controller.selection;
    if (selection.baseOffset == selection.extentOffset) return;
    final existing = _styleAttrs[Attribute.link.key]?.value as String?;
    final url = await showDialog<String>(
      context: context,
      builder: (ctx) {
        final ctrl = TextEditingController(text: existing ?? '');
        return AlertDialog(
          title: const Text('Link'),
          content: TextField(
            controller: ctrl,
            autofocus: true,
            decoration: const InputDecoration(hintText: 'https://…'),
          ),
          actions: [
            if (existing != null)
              TextButton(
                onPressed: () => Navigator.pop(ctx, ''),
                child: Text(
                  'Remove',
                  style: TextStyle(color: StrataPalette.coral),
                ),
              ),
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
              child: const Text('Apply'),
            ),
          ],
        );
      },
    );
    if (url == null || !mounted) return;
    if (url.isEmpty) {
      widget.controller.formatSelection(Attribute.clone(Attribute.link, null));
    } else {
      widget.controller.formatSelection(LinkAttribute(url));
    }
  }

  void _clearFormatting() {
    final controller = widget.controller;
    for (final attr in _styleAttrs.values) {
      controller.formatSelection(Attribute.clone(attr, null));
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget group(List<Widget> buttons) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < buttons.length; i++) ...[
          if (i > 0) const SizedBox(width: 2),
          buttons[i],
        ],
      ],
    );

    Widget gap() => Container(
      width: 1,
      height: 18,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      color: StrataPalette.outlineStrong,
    );

    final alignValue = _styleAttrs[Attribute.align.key]?.value as String?;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const ClampingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          group([
            _FmtBtn(
              label: 'B',
              tooltip: 'Bold',
              active: _has(Attribute.bold),
              onTap: () => _toggle(Attribute.bold),
            ),
            _FmtBtn(
              label: 'I',
              italic: true,
              tooltip: 'Italic',
              active: _has(Attribute.italic),
              onTap: () => _toggle(Attribute.italic),
            ),
            _FmtBtn(
              label: 'U',
              underline: true,
              tooltip: 'Underline',
              active: _has(Attribute.underline),
              onTap: () => _toggle(Attribute.underline),
            ),
            _FmtBtn(
              label: 'S',
              strike: true,
              tooltip: 'Strikethrough',
              active: _styleAttrs.containsKey('strike'),
              onTap: () => _toggle(Attribute.strikeThrough),
            ),
            _FmtBtn(
              icon: Icons.highlight_rounded,
              tooltip: _has(Attribute.background)
                  ? 'Remove highlight'
                  : 'Highlight',
              active: _has(Attribute.background),
              onTap: _toggleHighlight,
            ),
          ]),
          gap(),
          group([
            _FmtBtn(
              label: 'H1',
              tooltip: 'Heading 1',
              active: _styleAttrs[Attribute.header.key]?.value == 1,
              onTap: () => _setHeader(1),
            ),
            _FmtBtn(
              label: 'H2',
              tooltip: 'Heading 2',
              active: _styleAttrs[Attribute.header.key]?.value == 2,
              onTap: () => _setHeader(2),
            ),
            _FmtBtn(
              label: 'H3',
              tooltip: 'Heading 3',
              active: _styleAttrs[Attribute.header.key]?.value == 3,
              onTap: () => _setHeader(3),
            ),
            _FmtBtn(
              icon: Icons.notes_rounded,
              tooltip: 'Body text',
              active: !_styleAttrs.containsKey(Attribute.header.key),
              onTap: () => widget.controller.formatSelection(Attribute.header),
            ),
          ]),
          gap(),
          group([
            _FmtBtn(
              icon: Icons.format_list_bulleted_rounded,
              tooltip: 'Bullet list',
              active: _listValue == 'bullet',
              onTap: () => _toggleList(Attribute.ul),
            ),
            _FmtBtn(
              icon: Icons.format_list_numbered_rounded,
              tooltip: 'Numbered list',
              active: _listValue == 'ordered',
              onTap: () => _toggleList(Attribute.ol),
            ),
            _FmtBtn(
              icon: Icons.check_box_outlined,
              tooltip: 'Checklist',
              active: _listValue == 'checked' || _listValue == 'unchecked',
              onTap: () => _toggleList(Attribute.unchecked),
            ),
          ]),
          gap(),
          group([
            _FmtBtn(
              icon: Icons.format_quote_rounded,
              tooltip: 'Quote',
              active: _styleAttrs.containsKey('blockquote'),
              onTap: () => _toggle(Attribute.blockQuote),
            ),
            _FmtBtn(
              icon: Icons.code_rounded,
              tooltip: 'Code block',
              active: _styleAttrs.containsKey(Attribute.codeBlock.key),
              onTap: () => _toggle(Attribute.codeBlock),
            ),
            _FmtBtn(
              icon: Icons.code_off_outlined,
              tooltip: 'Inline code',
              active: _has(Attribute.inlineCode),
              onTap: () => _toggle(Attribute.inlineCode),
            ),
          ]),
          gap(),
          group([
            _FmtBtn(
              icon: Icons.format_align_left_rounded,
              tooltip: 'Align left',
              active: alignValue == null || alignValue == 'left',
              onTap: () => _setAlign('left'),
            ),
            _FmtBtn(
              icon: Icons.format_align_center_rounded,
              tooltip: 'Align center',
              active: alignValue == 'center',
              onTap: () => _setAlign('center'),
            ),
            _FmtBtn(
              icon: Icons.format_align_right_rounded,
              tooltip: 'Align right',
              active: alignValue == 'right',
              onTap: () => _setAlign('right'),
            ),
            _FmtBtn(
              icon: Icons.format_align_justify_rounded,
              tooltip: 'Justify',
              active: alignValue == 'justify',
              onTap: () => _setAlign('justify'),
            ),
          ]),
          gap(),
          group([
            _SpacingMenu(
              lineHeight: widget.lineHeight,
              paraSpacing: widget.paraSpacing,
              onLineHeightChanged: widget.onLineHeightChanged,
              onParaSpacingChanged: widget.onParaSpacingChanged,
            ),
          ]),
          gap(),
          group([
            _FmtBtn(
              icon: Icons.link_rounded,
              tooltip: 'Link',
              active: _styleAttrs.containsKey(Attribute.link.key),
              onTap: _editLink,
            ),
            _FmtBtn(
              icon: Icons.horizontal_rule_rounded,
              tooltip: 'Page break',
              onTap: widget.onInsertDivider,
            ),
            _FmtBtn(
              icon: Icons.format_clear_rounded,
              tooltip: 'Clear formatting',
              onTap: _clearFormatting,
            ),
          ]),
        ],
      ),
    );
  }
}

class _SpacingMenu extends StatelessWidget {
  const _SpacingMenu({
    required this.lineHeight,
    required this.paraSpacing,
    required this.onLineHeightChanged,
    required this.onParaSpacingChanged,
  });

  final double lineHeight;
  final double paraSpacing;
  final ValueChanged<double> onLineHeightChanged;
  final ValueChanged<double> onParaSpacingChanged;

  static const _lineOptions = <(String, double)>[
    ('Single', 1.0),
    ('1.15', 1.15),
    ('1.5', 1.5),
    ('Double', 2.0),
  ];

  static const _paraOptions = <(String, double)>[
    ('Small', 2.0),
    ('Medium', 4.0),
    ('Large', 8.0),
  ];

  @override
  Widget build(BuildContext context) {
    final tint = StrataPalette.onSurfaceMuted;
    return Tooltip(
      message: 'Spacing',
      waitDuration: const Duration(milliseconds: 500),
      child: PopupMenuButton<String>(
        onSelected: (value) {
          final parts = value.split('_');
          if (parts.length != 2) return;
          final val = double.tryParse(parts[1]);
          if (val == null) return;
          if (parts[0] == 'line') {
            onLineHeightChanged(val);
          } else if (parts[0] == 'para') {
            onParaSpacingChanged(val);
          }
        },
        color: StrataPalette.surfaceHigh,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: StrataPalette.outline),
        ),
        offset: const Offset(0, -8),
        itemBuilder: (_) => [
          PopupMenuItem<String>(
            enabled: false,
            padding: EdgeInsets.fromLTRB(14, 8, 14, 4),
            child: SizedBox(
              width: 120,
              child: Text(
                'LINE SPACING',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: .8,
                  color: StrataPalette.onSurfaceMuted,
                ),
              ),
            ),
          ),
          for (final (label, val) in _lineOptions)
            PopupMenuItem<String>(
              value: 'line_$val',
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
              child: Row(
                children: [
                  SizedBox(
                    width: 20,
                    child: (lineHeight - val).abs() < 0.01
                        ? const Icon(
                            Icons.check,
                            size: 15,
                            color: StrataPalette.accent,
                          )
                        : null,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: (lineHeight - val).abs() < 0.01
                          ? FontWeight.w700
                          : FontWeight.w500,
                      color: (lineHeight - val).abs() < 0.01
                          ? StrataPalette.accent
                          : tint,
                    ),
                  ),
                ],
              ),
            ),
          const PopupMenuDivider(height: 9),
          PopupMenuItem<String>(
            enabled: false,
            padding: EdgeInsets.fromLTRB(14, 8, 14, 4),
            child: SizedBox(
              width: 120,
              child: Text(
                'PARAGRAPH SPACING',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: .8,
                  color: StrataPalette.onSurfaceMuted,
                ),
              ),
            ),
          ),
          for (final (label, val) in _paraOptions)
            PopupMenuItem<String>(
              value: 'para_$val',
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
              child: Row(
                children: [
                  SizedBox(
                    width: 20,
                    child: (paraSpacing - val).abs() < 0.01
                        ? const Icon(
                            Icons.check,
                            size: 15,
                            color: StrataPalette.accent,
                          )
                        : null,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: (paraSpacing - val).abs() < 0.01
                          ? FontWeight.w700
                          : FontWeight.w500,
                      color: (paraSpacing - val).abs() < 0.01
                          ? StrataPalette.accent
                          : tint,
                    ),
                  ),
                ],
              ),
            ),
        ],
        child: Container(
          width: 32,
          height: 30,
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(8)),
          alignment: Alignment.center,
          child: Icon(Icons.format_line_spacing_rounded, size: 16, color: tint),
        ),
      ),
    );
  }
}

class _FmtBtn extends StatefulWidget {
  const _FmtBtn({
    this.icon,
    this.label,
    this.tooltip,
    this.active = false,
    this.italic = false,
    this.underline = false,
    this.strike = false,
    required this.onTap,
  });

  final IconData? icon;
  final String? label;
  final String? tooltip;
  final bool active;
  final bool italic;
  final bool underline;
  final bool strike;
  final VoidCallback onTap;

  @override
  State<_FmtBtn> createState() => _FmtBtnState();
}

class _FmtBtnState extends State<_FmtBtn> {
  double _scale = 1.0;

  void _onTapDown(_) => setState(() => _scale = 0.88);
  void _onTapUp(_) => setState(() => _scale = 1.0);
  void _onTapCancel() => setState(() => _scale = 1.0);

  @override
  Widget build(BuildContext context) {
    final tint = widget.active
        ? StrataPalette.accent
        : StrataPalette.onSurfaceMuted;
    return Tooltip(
      message: widget.tooltip ?? '',
      waitDuration: const Duration(milliseconds: 500),
      child: GestureDetector(
        onTap: widget.onTap,
        onTapDown: _onTapDown,
        onTapUp: _onTapUp,
        onTapCancel: _onTapCancel,
        child: AnimatedScale(
          scale: _scale,
          duration: const Duration(milliseconds: 100),
          curve: Curves.easeOutCubic,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 140),
            width: 32,
            height: 30,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: widget.active
                  ? StrataPalette.accent.withValues(alpha: .16)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: widget.active
                    ? StrataPalette.accent.withValues(alpha: .38)
                    : Colors.transparent,
              ),
            ),
            child: widget.label != null
                ? Text(
                    widget.label!,
                    style: TextStyle(
                      fontSize: widget.label!.length > 1 ? 12 : 15,
                      fontWeight: FontWeight.w800,
                      fontStyle: widget.italic
                          ? FontStyle.italic
                          : FontStyle.normal,
                      decoration: widget.underline
                          ? TextDecoration.underline
                          : widget.strike
                          ? TextDecoration.lineThrough
                          : TextDecoration.none,
                      color: tint,
                      height: 1.0,
                    ),
                  )
                : Icon(widget.icon, size: 16, color: tint),
          ),
        ),
      ),
    );
  }
}

class _StatBlock extends StatelessWidget {
  const _StatBlock({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: StrataPalette.onBackground,
            height: 1.1,
          ),
        ),
        Text(
          label.toUpperCase(),
          style: TextStyle(
            fontSize: 7.5,
            fontWeight: FontWeight.w700,
            letterSpacing: .8,
            color: StrataPalette.onSurfaceMuted,
          ),
        ),
      ],
    );
  }
}

class _UndoRedoBtn extends StatelessWidget {
  const _UndoRedoBtn({
    required this.icon,
    required this.enabled,
    required this.onTap,
  });

  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: enabled ? StrataPalette.surfaceHighest : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Icon(
          icon,
          size: 17,
          color: enabled
              ? StrataPalette.onBackground
              : StrataPalette.onSurfaceMuted.withValues(alpha: .35),
        ),
      ),
    );
  }
}

class _SearchBtn extends StatelessWidget {
  const _SearchBtn({
    required this.icon,
    required this.enabled,
    required this.onTap,
  });

  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        width: 28,
        height: 28,
        margin: const EdgeInsets.symmetric(horizontal: 1),
        decoration: BoxDecoration(
          color: enabled ? StrataPalette.surfaceHighest : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Icon(
          icon,
          size: 18,
          color: enabled
              ? StrataPalette.onBackground
              : StrataPalette.onSurfaceMuted.withValues(alpha: .4),
        ),
      ),
    );
  }
}

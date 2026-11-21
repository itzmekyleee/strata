import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_quill/flutter_quill.dart';

import 'table_embed.dart';

class TableEmbedBuilder extends EmbedBuilder {
  const TableEmbedBuilder();

  @override
  String get key => StrataTableEmbed.tableType;

  @override
  Widget build(BuildContext context, EmbedContext embedContext) {
    final cells = StrataTableEmbed.parse(embedContext.node.value.data);
    return _StaticTable(
      cells: cells,
      onTap: embedContext.readOnly
          ? null
          : () => _edit(context, embedContext, cells),
    );
  }

  Future<void> _edit(
    BuildContext context,
    EmbedContext embedContext,
    List<List<String>> initial,
  ) async {
    final result = await showModalBottomSheet<List<List<String>>>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _TableBottomSheet(initial: initial),
    );
    if (result != null) {
      final controller = embedContext.controller;
      final offset = embedContext.node.offset;
      controller.replaceText(
        offset,
        1,
        StrataTableEmbed.fromCells(result),
        null,
      );
      // Ensure a paragraph exists after the table for cursor escape.
      final after = controller.selection.baseOffset;
      if (after >= controller.document.length - 1) {
        controller.replaceText(after, 0, '\n', null);
      }
    }
  }
}

// ── Read-only table display ────────────────────────────────────────────────

class _StaticTable extends StatelessWidget {
  const _StaticTable({required this.cells, this.onTap});

  final List<List<String>> cells;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest.withValues(
            alpha: .30,
          ),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: theme.colorScheme.outlineVariant.withValues(alpha: .4),
          ),
        ),
        child: Table(
          border: TableBorder.all(
            color: theme.dividerColor.withValues(alpha: .5),
            borderRadius: BorderRadius.circular(11),
            width: 1,
          ),
          defaultVerticalAlignment: TableCellVerticalAlignment.middle,
          children: [
            for (final row in cells)
              TableRow(
                children: [
                  for (final cell in row)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 7,
                      ),
                      child: Text(
                        cell.isEmpty ? ' ' : cell,
                        style: theme.textTheme.bodyMedium,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

// ── Table editing bottom sheet ─────────────────────────────────────────────

class _TableBottomSheet extends StatefulWidget {
  const _TableBottomSheet({required this.initial});

  final List<List<String>> initial;

  @override
  State<_TableBottomSheet> createState() => _TableBottomSheetState();
}

class _TableBottomSheetState extends State<_TableBottomSheet> {
  late List<List<String>> _grid;
  int _activeRow = 0;
  int _activeCol = 0;
  final _cellFocus = FocusNode();
  final _cellController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _grid = [
      for (final row in widget.initial) [...row],
    ];
    _syncCellToEditor();
  }

  @override
  void dispose() {
    _cellFocus.dispose();
    _cellController.dispose();
    super.dispose();
  }

  /// Push the current editor text back into the active cell.
  void _saveActiveCell() {
    if (_activeRow < _grid.length && _activeCol < _grid[_activeRow].length) {
      _grid[_activeRow][_activeCol] = _cellController.text;
    }
  }

  /// Load the active cell's content into the editor.
  void _syncCellToEditor() {
    if (_activeRow < _grid.length && _activeCol < _grid[_activeRow].length) {
      _cellController.text = _grid[_activeRow][_activeCol];
      _cellController.selection = TextSelection.collapsed(
        offset: _cellController.text.length,
      );
    }
  }

  void _moveTo(int row, int col) {
    _saveActiveCell();
    setState(() {
      _activeRow = row.clamp(0, _grid.length - 1);
      _activeCol = col.clamp(0, _grid[_activeRow].length - 1);
      _syncCellToEditor();
    });
    _cellFocus.requestFocus();
  }

  void _addRow() {
    _saveActiveCell();
    final width = _grid.isEmpty ? 2 : _grid.first.length;
    setState(() => _grid.add(List.filled(width, '')));
  }

  void _addColumn() {
    _saveActiveCell();
    setState(() {
      for (final row in _grid) {
        row.add('');
      }
    });
  }

  void _removeRow(int index) {
    if (_grid.length <= 1) return;
    _saveActiveCell();
    setState(() {
      _grid.removeAt(index);
      if (_activeRow >= _grid.length) {
        _activeRow = _grid.length - 1;
      }
      _syncCellToEditor();
    });
  }

  void _removeColumn(int index) {
    if (_grid.isEmpty || _grid.first.length <= 1) return;
    _saveActiveCell();
    setState(() {
      for (final row in _grid) {
        if (index < row.length) row.removeAt(index);
      }
      if (_activeCol >= _grid[_activeRow].length) {
        _activeCol = _grid[_activeRow].length - 1;
      }
      _syncCellToEditor();
    });
  }

  void _handleKey(KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) return;
    final key = event.logicalKey;

    if (key == LogicalKeyboardKey.tab) {
      final shift = HardwareKeyboard.instance.isShiftPressed;
      _navigateCell(shift: shift);
    } else if (key == LogicalKeyboardKey.escape) {
      _saveActiveCell();
      Navigator.of(context).pop(_grid);
    }
  }

  void _navigateCell({required bool shift}) {
    _saveActiveCell();
    var row = _activeRow;
    var col = _activeCol;
    if (shift) {
      col--;
      if (col < 0) {
        row--;
        if (row >= 0) {
          col = _grid[row].length - 1;
        } else {
          col = 0;
          _syncCellToEditor();
          return;
        }
      }
    } else {
      col++;
      if (col >= _grid[row].length) {
        col = 0;
        row++;
        if (row >= _grid.length) {
          _syncCellToEditor();
          return;
        }
      }
    }
    _moveTo(row, col);
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.viewInsetsOf(context).bottom;
    final theme = Theme.of(context);
    final rows = _grid.length;
    final cols = _grid.isEmpty ? 0 : _grid.first.length;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomPadding),
      child: Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHigh,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
          border: Border(
            top: BorderSide(
              color: theme.colorScheme.outlineVariant.withValues(alpha: .4),
            ),
          ),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Drag handle
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(top: 10, bottom: 6),
                  decoration: BoxDecoration(
                    color: theme.dividerColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              // Header: title + size badge
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 16, 0),
                child: Row(
                  children: [
                    Text(
                      'Table',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surface,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '$rows × $cols',
                        style: theme.textTheme.labelSmall?.copyWith(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      tooltip: 'Delete table',
                      onPressed: () {
                        _saveActiveCell();
                        Navigator.of(context).pop(null);
                      },
                      icon: Icon(
                        Icons.delete_outline_rounded,
                        size: 20,
                        color: theme.colorScheme.error,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              // Grid preview
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _GridPreview(
                    grid: _grid,
                    activeRow: _activeRow,
                    activeCol: _activeCol,
                    onCellTap: _moveTo,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              // Active cell editor
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: KeyboardListener(
                  focusNode: FocusNode(),
                  onKeyEvent: _handleKey,
                  child: TextField(
                    controller: _cellController,
                    focusNode: _cellFocus,
                    maxLines: null,
                    style: theme.textTheme.bodyLarge,
                    decoration: InputDecoration(
                      hintText: 'Cell content',
                      isDense: true,
                      filled: true,
                      fillColor: theme.colorScheme.surface,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: theme.colorScheme.primary.withValues(alpha: .3),
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: theme.colorScheme.primary,
                          width: 1.5,
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: theme.colorScheme.outlineVariant
                              .withValues(alpha: .3),
                        ),
                      ),
                    ),
                    onChanged: (value) {
                      if (_activeRow < _grid.length &&
                          _activeCol < _grid[_activeRow].length) {
                        _grid[_activeRow][_activeCol] = value;
                      }
                    },
                  ),
                ),
              ),
              const SizedBox(height: 12),
              // Action chips
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _ActionChip(
                        icon: Icons.add_circle_outline_rounded,
                        label: 'Row',
                        onTap: _addRow,
                      ),
                      const SizedBox(width: 6),
                      _ActionChip(
                        icon: Icons.view_column_outlined,
                        label: 'Col',
                        onTap: _addColumn,
                      ),
                      const SizedBox(width: 6),
                      _ActionChip(
                        icon: Icons.remove_circle_outline_rounded,
                        label: 'Row',
                        onTap: _grid.length > 1
                            ? () => _removeRow(_activeRow)
                            : null,
                      ),
                      const SizedBox(width: 6),
                      _ActionChip(
                        icon: Icons.view_carousel_outlined,
                        label: 'Col',
                        onTap: cols > 1
                            ? () => _removeColumn(_activeCol)
                            : null,
                      ),
                    ],
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

// ── Grid preview with active cell highlight ────────────────────────────────

class _GridPreview extends StatelessWidget {
  const _GridPreview({
    required this.grid,
    required this.activeRow,
    required this.activeCol,
    required this.onCellTap,
  });

  final List<List<String>> grid;
  final int activeRow;
  final int activeCol;
  final void Function(int row, int col) onCellTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (grid.isEmpty) return const SizedBox.shrink();

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: .3),
        ),
      ),
      child: Table(
        border: TableBorder.all(
          color: theme.dividerColor.withValues(alpha: .4),
          borderRadius: BorderRadius.circular(11),
          width: 1,
        ),
        defaultVerticalAlignment: TableCellVerticalAlignment.middle,
        children: [
          for (var r = 0; r < grid.length; r++)
            TableRow(
              children: [
                for (var c = 0; c < grid[r].length; c++)
                  GestureDetector(
                    onTap: () => onCellTap(r, c),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: r == activeRow && c == activeCol
                            ? theme.colorScheme.primary.withValues(alpha: .12)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(11),
                      ),
                      child: Text(
                        grid[r][c].isEmpty ? ' ' : grid[r][c],
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: grid[r][c].isEmpty
                              ? theme.colorScheme.onSurface.withValues(
                                  alpha: .3,
                                )
                              : theme.colorScheme.onSurface,
                          fontWeight:
                              r == activeRow && c == activeCol
                                  ? FontWeight.w600
                                  : FontWeight.w400,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

// ── Action chip for row/col manipulation ───────────────────────────────────

class _ActionChip extends StatelessWidget {
  const _ActionChip({
    required this.icon,
    required this.label,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final enabled = onTap != null;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: enabled
              ? theme.colorScheme.surface
              : theme.colorScheme.surface.withValues(alpha: .5),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: theme.colorScheme.outlineVariant.withValues(alpha: .25),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: enabled
                  ? theme.colorScheme.onSurface
                  : theme.colorScheme.onSurface.withValues(alpha: .3),
            ),
            const SizedBox(width: 5),
            Text(
              label,
              style: theme.textTheme.labelMedium?.copyWith(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: enabled
                    ? theme.colorScheme.onSurface
                    : theme.colorScheme.onSurface.withValues(alpha: .3),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

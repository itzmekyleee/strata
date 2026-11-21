/// Neutral block model shared by the PDF and DOCX exporters so both render
/// the exact same structure extracted from a quill delta.
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_quill/flutter_quill.dart';

enum NoteAlign { left, center, right, justify }

class NoteRun {
  const NoteRun({
    required this.text,
    this.bold = false,
    this.italic = false,
    this.underline = false,
    this.strike = false,
    this.code = false,
    this.color,
  });

  final String text;
  final bool bold;
  final bool italic;
  final bool underline;
  final bool strike;
  final bool code;

  /// 0xAARRGGBB or null for default color.
  final int? color;
}

sealed class NoteBlock {
  const NoteBlock();
}

class HeadingBlock extends NoteBlock {
  const HeadingBlock(this.level, this.runs);

  /// 1..3
  final int level;
  final List<NoteRun> runs;
}

class ParagraphBlock extends NoteBlock {
  const ParagraphBlock(this.runs, {this.align = NoteAlign.left});

  final List<NoteRun> runs;
  final NoteAlign align;
}

class ListItemBlock extends NoteBlock {
  const ListItemBlock({
    required this.marker,
    required this.indent,
    required this.runs,
  });

  /// Precomputed marker text: '•' or '1.', '2.', …
  final String marker;
  final int indent;
  final List<NoteRun> runs;
}

class TableBlock extends NoteBlock {
  const TableBlock(this.rows);

  /// rows.first is the header row; all rows have `cols` cells.
  final List<List<String>> rows;
}

class ImageBlock extends NoteBlock {
  const ImageBlock(this.bytes);

  final Uint8List bytes;
}

/// A page-break divider rendered as a horizontal rule.
class DividerBlock extends NoteBlock {
  const DividerBlock();
}

/// Converts a quill [Document] into the block IR above.
///
/// [resolveImage] maps an embed source (data URI or stored attachment
/// path) to raw bytes; return null to skip that image.
List<NoteBlock> documentToBlocks(
  Document document, {
  Uint8List? Function(String source)? resolveImage,
}) {
  final blocks = <NoteBlock>[];
  var orderedCounter = 0;

  void addEmbed(Embed embed) {
    final data = embed.value.data.toString();
    switch (embed.value.type) {
      case 'image':
        if (resolveImage == null) return;
        final bytes = resolveImage(data);
        if (bytes != null && bytes.isNotEmpty) {
          blocks.add(ImageBlock(bytes));
        }
      case 'table':
        final cells = parseTableEmbed(data);
        if (cells.isNotEmpty) blocks.add(TableBlock(cells));
      case 'divider':
        blocks.add(const DividerBlock());
    }
  }

  void addLine(Line line) {
    final attrs = line.style.attributes;
    final isOrdered = attrs[Attribute.ol.key]?.value == 'ordered';
    final isBullets = attrs[Attribute.ul.key] != null;
    final indent =
        (attrs[Attribute.indent.key]?.value as num?)?.toInt() ?? 0;

    // Lines made up entirely of embeds become image blocks.
    final embeds = line.children.whereType<Embed>().toList();
    if (embeds.isNotEmpty && embeds.length == line.children.length) {
      orderedCounter = 0;
      for (final e in embeds) {
        addEmbed(e);
      }
      return;
    }

    final runs = _lineToRuns(line);
    if (isOrdered) {
      orderedCounter++;
      blocks.add(
        ListItemBlock(marker: '$orderedCounter.', indent: indent, runs: runs),
      );
    } else if (isBullets) {
      blocks.add(ListItemBlock(marker: '•', indent: indent, runs: runs));
    } else {
      orderedCounter = 0;
      final header = attrs[Attribute.header.key]?.value;
      final align = switch (attrs[Attribute.align.key]?.value) {
        'center' => NoteAlign.center,
        'right' => NoteAlign.right,
        'justify' => NoteAlign.justify,
        _ => NoteAlign.left,
      };
      if (header is num && header >= 1 && header <= 3) {
        blocks.add(HeadingBlock(header.toInt(), runs));
      } else {
        blocks.add(ParagraphBlock(runs, align: align));
      }
    }
  }

  for (final node in document.root.children) {
    switch (node) {
      case Line():
        addLine(node);
      case Block():
        orderedCounter = 0;
        for (final child in node.children.whereType<Line>()) {
          addLine(child);
        }
      case Embed():
        orderedCounter = 0;
        addEmbed(node);
    }
  }
  return blocks;
}

List<NoteRun> _lineToRuns(Line line) {
  return [
    for (final child in line.children)
      if (child is! Embed)
        () {
          final st = child.style.attributes;
          int? color;
          final c = st[Attribute.color.key]?.value as String?;
          if (c != null && c.length >= 7) {
            color = int.tryParse(c.replaceFirst('#', '0xFF'));
          }
          return NoteRun(
            text: child is QuillText ? child.value : '',
            bold: st.containsKey(Attribute.bold.key),
            italic: st.containsKey(Attribute.italic.key),
            underline: st.containsKey(Attribute.underline.key),
            strike: st.containsKey('strike'),
            code: st.containsKey('code'),
            color: color,
          );
        }(),
  ];
}

/// Parses the table-embed payload into a rectangular grid of strings.
/// Returns an empty list when the payload is corrupt.
List<List<String>> parseTableEmbed(String data) {
  try {
    final map = jsonDecode(data) as Map<String, dynamic>;
    final cols = (map['cols'] as num?)?.toInt() ?? 1;
    final rows = (map['rows'] as num?)?.toInt() ?? 0;
    final raw = (map['cells'] as List?)?.cast<String>() ?? const [];
    return [
      for (var r = 0; r < rows; r++)
        [
          for (var c = 0; c < cols; c++)
            (r * cols + c) < raw.length ? raw[r * cols + c] : '',
        ],
    ];
  } catch (_) {
    return const [];
  }
}

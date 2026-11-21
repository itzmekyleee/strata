import 'dart:convert';

import 'package:flutter_quill/flutter_quill.dart';
import 'package:path/path.dart' as p;

/// Converts a Quill delta document into GitHub-flavored Markdown.
///
/// Supported: headings h1–h6, bold/italic/strike/inline-code, links,
/// bullet & numbered lists (with indent levels), blockquotes, fenced code
/// blocks, images (as relative file names) and tables (GFM pipe syntax).
abstract final class DeltaToMarkdown {
  static String convert(String deltaJson, {String title = ''}) {
    List<dynamic> raw;
    try {
      raw = jsonDecode(deltaJson.isEmpty ? '[]' : deltaJson) as List<dynamic>;
    } catch (_) {
      raw = const [];
    }
    final Document doc;
    try {
      doc = Document.fromJson(raw);
    } catch (_) {
      return '';
    }

    final out = StringBuffer();
    if (title.trim().isNotEmpty) {
      out.writeln('# ${title.trim()}');
    }

    for (final node in doc.root.children) {
      if (node is Line) {
        _emitLine(node, out);
        continue;
      }

      if (node is Block) {
        final lines = node.children.whereType<Line>().toList();
        if (lines.isEmpty) continue;
        final attrs = lines.first.style.attributes;
        final isCodeBlock = attrs.containsKey('code-block');
        final isQuote = attrs['blockquote'] != null;
        final isList =
            attrs[Attribute.ul.key] != null ||
            attrs[Attribute.ol.key]?.value == 'ordered';

        if (isCodeBlock) {
          out.writeln('```');
          for (final l in lines) {
            out.writeln(_inline(l));
          }
          out.writeln('```');
        } else if (isList) {
          var orderedRun = 0;
          for (final l in lines) {
            final a = l.style.attributes;
            final isOrdered = a[Attribute.ol.key]?.value == 'ordered';
            final indent =
                (a[Attribute.indent.key]?.value as num?)?.toInt() ?? 0;
            final pad = '  ' * indent.clamp(0, 8);
            String marker;
            if (isOrdered) {
              orderedRun += 1;
              marker = '$orderedRun.';
            } else {
              orderedRun = 0;
              marker = '-';
            }
            out.write('$pad$marker ${_inline(l)}\n');
            for (final e in _lineEmbeds(l)) {
              out.write('$pad\n$e\n');
            }
          }
        } else {
          final prefix = isQuote ? '> ' : '';
          for (final l in lines) {
            final text = _inline(l);
            if (text.isNotEmpty || prefix.isEmpty) {
              out.writeln('$prefix$text');
            }
            for (final e in _lineEmbeds(l)) {
              out.writeln('$prefix$e');
            }
          }
        }
        continue;
      }

      if (node is Embed) {
        final md = _embedToMarkdown(node);
        if (md != null) {
          out.writeln(md);
        }
      }
    }
    return out.toString();
  }

  static void _emitLine(Line node, StringBuffer out) {
    final attrs = node.style.attributes;
    final embeds = _lineEmbeds(node);
    final text = _inline(node);
    final header = attrs[Attribute.header.key]?.value;

    if (header is num && header >= 1 && header <= 6) {
      out.writeln('${'#' * header.toInt()} $text');
    } else if (text.isNotEmpty || embeds.isEmpty) {
      out.writeln(text);
    }
    for (final e in embeds) {
      out.writeln(e);
      out.writeln();
    }
  }

  static List<String> _lineEmbeds(Line line) => [
    for (final child in line.children)
      if (child is Embed) ?_embedToMarkdown(child),
  ];

  static String _inline(Line line) {
    final buf = StringBuffer();
    for (final child in line.children) {
      if (child is Embed) continue;
      final text = child is QuillText ? child.value : '';
      if (text.isEmpty) continue;
      final st = child.style.attributes;
      if (st.containsKey(Attribute.inlineCode.key)) {
        buf.write('`${text.replaceAll('`', "'")}`');
        continue;
      }
      final link = st[Attribute.link.key]?.value as String?;
      if (link != null && link.isNotEmpty) {
        buf.write('[${_escape(text)}]($link)');
        continue;
      }
      var t = _escape(text);
      if (st.containsKey('strike')) t = '~~$t~~';
      if (st.containsKey(Attribute.italic.key)) t = '_${t}_';
      if (st.containsKey(Attribute.bold.key)) t = '**$t**';
      buf.write(t);
    }
    return buf.toString().trimRight();
  }

  static String? _embedToMarkdown(Embed embed) {
    switch (embed.value.type) {
      case 'image':
        final src = embed.value.data.toString();
        if (src.startsWith('data:')) return '![image](embedded-image)';
        return '![image](${p.basename(src.split('?').first)})';
      case 'table':
        return _table(embed.value.data.toString());
      case 'divider':
        return '---';
      default:
        return null;
    }
  }

  static String _table(String data) {
    List<List<String>> rows;
    try {
      final map = jsonDecode(data) as Map<String, dynamic>;
      final cols = (map['cols'] as num?)?.toInt() ?? 1;
      final rowCount = (map['rows'] as num?)?.toInt() ?? 0;
      final flat = (map['cells'] as List?)?.cast<String>() ?? const [];
      rows = [
        for (var r = 0; r < rowCount; r++)
          [
            for (var c = 0; c < cols; c++)
              (r * cols + c) < flat.length ? flat[r * cols + c] : '',
          ],
      ];
    } catch (_) {
      return '';
    }
    if (rows.isEmpty) return '';
    final width = rows.fold<int>(0, (w, r) => r.length > w ? r.length : w);
    String cell(String s) => s.replaceAll('|', '\\|').replaceAll('\n', ' ');
    final head = [...rows.first];
    while (head.length < width) {
      head.add('');
    }
    final buf = StringBuffer();
    buf.write('| ${head.map(cell).join(' | ')} |\n');
    buf.write('| ${List.filled(width, '---').join(' | ')} |\n');
    for (final row in rows.skip(1)) {
      final padded = [...row];
      while (padded.length < width) {
        padded.add('');
      }
      buf.write('| ${padded.map(cell).join(' | ')} |\n');
    }
    return buf.toString().trimRight();
  }

  static final RegExp _specials = RegExp(r'([\\`*_\[\]])');

  static String _escape(String s) =>
      s.replaceAllMapped(_specials, (m) => '\\${m[1]}');
}

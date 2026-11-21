import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:strata/data/services/divider_embed.dart';
import 'package:strata/data/services/delta_to_docx.dart';
import 'package:strata/data/services/delta_to_markdown.dart';
import 'package:strata/data/services/note_blocks.dart';

void main() {
  group('divider embed', () {
    test('survives a delta JSON round-trip', () {
      final doc = Document()..insert(0, StrataDividerEmbed());
      final json = jsonEncode(doc.toDelta().toJson());
      final restored = Document.fromJson(jsonDecode(json) as List);
      final embeds = [
        for (final line in restored.root.children.whereType<Line>())
          ...line.children.whereType<Embed>(),
      ];
      expect(embeds, hasLength(1));
      expect(embeds.single.value.type, 'divider');
    });

    test('documentToBlocks extracts a DividerBlock', () {
      final doc = Document.fromJson([
        {'insert': 'before\n'},
        {'insert': {'divider': 'line'}},
        {'insert': '\nafter\n'},
      ]);
      final blocks = documentToBlocks(doc);
      expect(blocks.whereType<DividerBlock>(), hasLength(1));
    });

    test('markdown export renders ---', () {
      final md = DeltaToMarkdown.convert(
        jsonEncode([
          {'insert': {'divider': 'line'}},
          {'insert': '\n'},
        ]),
      );
      expect(md, contains('---'));
    });

    test('docx export draws a bordered rule paragraph', () {
      final bytes = buildDocx(title: '', blocks: const [DividerBlock()]);
      final archive = ZipDecoder().decodeBytes(bytes);
      final xml = utf8.decode(
        archive.findFile('word/document.xml')!.content as List<int>,
      );
      expect(xml, contains('<w:pBdr>'));
    });
  });
}

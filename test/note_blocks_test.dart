import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:strata/data/services/delta_to_docx.dart';
import 'package:strata/data/services/note_blocks.dart';

Document _doc(List<dynamic> ops) =>
    Document.fromJson([for (final op in ops) op as Map<String, dynamic>]);

// Minimal valid PNG: 8-byte signature + IHDR length/type + 4x4 dims.
Uint8List _pngBytes({int width = 4, int height = 3}) => Uint8List.fromList([
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, //
  0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52,
  (width >> 24) & 0xFF, (width >> 16) & 0xFF, (width >> 8) & 0xFF,
  width & 0xFF,
  (height >> 24) & 0xFF, (height >> 16) & 0xFF, (height >> 8) & 0xFF,
  height & 0xFF,
  0x08, 0x06, 0x00, 0x00, 0x00,
]);

void main() {
  group('documentToBlocks', () {
    test('plain text becomes a paragraph', () {
      final blocks = documentToBlocks(
        _doc([
          {'insert': 'Hello world\n'},
        ]),
      );
      expect(blocks, hasLength(1));
      final p = blocks.single as ParagraphBlock;
      expect(p.runs.single.text, 'Hello world');
    });

    test('headings are extracted with level', () {
      final blocks = documentToBlocks(
        _doc([
          {'insert': 'Big'},
          {
            'insert': '\n',
            'attributes': {'header': 1},
          },
          {'insert': 'Small'},
          {
            'insert': '\n',
            'attributes': {'header': 3},
          },
        ]),
      );
      expect((blocks[0] as HeadingBlock).level, 1);
      expect((blocks[1] as HeadingBlock).level, 3);
    });

    test('inline styles map to runs', () {
      final blocks = documentToBlocks(
        _doc([
          {
            'attributes': {'bold': true},
            'insert': 'bold',
          },
          {'insert': ' and '},
          {
            'attributes': {'italic': true, 'color': '#FF0000'},
            'insert': 'red',
          },
          {'insert': '\n'},
        ]),
      );
      final runs = (blocks.single as ParagraphBlock).runs;
      expect(runs[0].bold, isTrue);
      expect(runs[1].text, ' and ');
      expect(runs[2].italic, isTrue);
      expect(runs[2].color, 0xFFFF0000);
    });

    test('ordered lists number consecutively and reset on paragraph', () {
      final blocks = documentToBlocks(
        _doc([
          {'insert': 'one\n'},
          {
            'insert': 'two\n',
            'attributes': {'list': 'ordered'},
          },
          {
            'insert': 'three\n',
            'attributes': {'list': 'ordered'},
          },
          {'insert': 'para\n'},
          {
            'insert': 'four\n',
            'attributes': {'list': 'ordered'},
          },
        ]),
      );
      final items = blocks.whereType<ListItemBlock>().toList();
      // Consecutive ordered lines group into one quill Block → numbering
      // restarts at each block/paragraph break.
      expect(items.map((i) => i.marker), ['1.', '2.', '1.']);
    });

    test('bullets keep their marker', () {
      final blocks = documentToBlocks(
        _doc([
          {
            'insert': 'a\n',
            'attributes': {'list': 'bullet'},
          },
        ]),
      );
      expect((blocks.single as ListItemBlock).marker, '•');
    });

    test('table embeds become TableBlock grids', () {
      final data = jsonEncode({
        'cols': 2,
        'rows': 2,
        'cells': ['H1', 'H2', 'A', 'B'],
      });
      final blocks = documentToBlocks(
        _doc([
          {
            'insert': {'table': data},
          },
          {'insert': '\n'},
        ]),
      );
      final t = blocks.whereType<TableBlock>().single;
      expect(t.rows, [
        ['H1', 'H2'],
        ['A', 'B'],
      ]);
    });

    test('image embeds resolve through the injected resolver', () {
      final png = _pngBytes();
      final blocks = documentToBlocks(
        _doc([
          {
            'insert': {'image': 'attachments://pic.png'},
          },
          {'insert': '\n'},
        ]),
        resolveImage: (src) => src.contains('pic') ? png : null,
      );
      expect((blocks.single as ImageBlock).bytes, same(png));
    });

    test('corrupt table payload is skipped silently', () {
      final blocks = documentToBlocks(
        _doc([
          {
            'insert': {'table': 'not-json'},
          },
          {'insert': '\n'},
        ]),
      );
      expect(blocks.whereType<TableBlock>(), isEmpty);
    });
  });

  group('buildDocx', () {
    Uint8List build(List<NoteBlock> blocks, {String title = 'My Note'}) =>
        buildDocx(title: title, blocks: blocks);

    String documentXml(Uint8List docx) {
      final archive = ZipDecoder().decodeBytes(docx);
      return utf8.decode(
        archive.firstWhere((f) => f.name == 'word/document.xml').content
            as List<int>,
      );
    }

    Archive entries(Uint8List docx) => ZipDecoder().decodeBytes(docx);

    test('produces a zip with required OPC parts', () {
      final docx = build([
        ParagraphBlock([const NoteRun(text: 'hi')]),
      ]);
      final names = entries(docx).map((f) => f.name);
      expect(
        names,
        containsAll([
          '[Content_Types].xml',
          '_rels/.rels',
          'word/document.xml',
          'word/_rels/document.xml.rels',
        ]),
      );
    });

    test('title renders as bold large run in first paragraph', () {
      final xml = documentXml(build([]));
      expect(xml, contains('<w:t xml:space="preserve">My Note</w:t>'));
      expect(xml, contains('<w:b/>'));
      expect(xml, contains('w:val="52"'));
    });

    test('runs carry formatting attributes', () {
      final xml = documentXml(
        build([
          ParagraphBlock([
            const NoteRun(text: 'loud', bold: true),
            const NoteRun(
              text: 'fancy',
              italic: true,
              underline: true,
              strike: true,
              color: 0xFF00AA55,
            ),
            const NoteRun(text: '', bold: true),
          ]),
        ]),
      );
      expect(xml, contains('<w:b/>'));
      expect(xml, contains('<w:i/>'));
      expect(xml, contains('<w:u w:val="single"/>'));
      expect(xml, contains('<w:strike/>'));
      expect(xml, contains('<w:color w:val="00AA55"/>'));
      // Empty runs emit nothing.
      expect(xml.indexOf('loud'), lessThan(xml.indexOf('fancy')));
    });

    test('xml special characters are escaped', () {
      final xml = documentXml(
        build([
          ParagraphBlock([const NoteRun(text: '<b>&"')]),
        ]),
      );
      expect(xml, contains('&lt;b&gt;&amp;&quot;'));
    });

    test('lists get indents and markers', () {
      final xml = documentXml(
        build([
          ListItemBlock(
            marker: '1.',
            indent: 1,
            runs: [const NoteRun(text: 'x')],
          ),
        ]),
      );
      expect(xml, contains('>1.</w:t>'));
      expect(xml, contains('<w:tab/>'));
      expect(xml, contains('w:left="720" w:hanging="240"'));
    });

    test('tables render bordered grid with shaded header', () {
      final xml = documentXml(
        build([
          TableBlock([
            ['H', 'H'],
            ['a', 'b'],
          ]),
        ]),
      );
      expect(xml, contains('<w:tbl>'));
      expect(xml, contains('<w:shd w:val="clear" w:fill="F2F4F7"/>'));
      expect(xml, contains('w:insideV'));
      expect(xml.split('<w:tr>').length - 1, 2);
    });

    test('center alignment maps to w:jc', () {
      final xml = documentXml(
        build([
          ParagraphBlock([const NoteRun(text: 'mid')], align: NoteAlign.center),
        ]),
      );
      expect(xml, contains('<w:jc w:val="center"/>'));
    });

    test('images land in media with relationships and dimensions', () {
      final png = _pngBytes(width: 100, height: 50);
      final docx = buildDocx(title: '', blocks: [ImageBlock(png)]);
      final names = entries(docx).map((f) => f.name).toList();
      expect(names, contains('word/media/image1.png'));
      final rels = utf8.decode(
        entries(docx)
                .firstWhere((f) => f.name == 'word/_rels/document.xml.rels')
                .content
            as List<int>,
      );
      expect(rels, contains('Target="media/image1.png"'));
      final xml = documentXml(docx);
      // 100px * 9525 EMU/px.
      expect(xml, contains('cx="952500"'));
      // 50px * 9525.
      expect(xml, contains('cy="476250"'));
      expect(xml, contains('r:embed="rId100"'));
    });

    test('oversized images are clamped to column width', () {
      final png = _pngBytes(width: 2000, height: 1000);
      final xml = documentXml(buildDocx(title: '', blocks: [ImageBlock(png)]));
      expect(xml, contains('cx="5667375"'));
      // Height scaled proportionally: 1000 * 595/2000 = 297.5px.
      expect(xml, contains('cy="2833688"'));
    });

    test('unsupported image bytes are skipped entirely', () {
      final docx = buildDocx(
        title: '',
        blocks: [
          ImageBlock(Uint8List.fromList([1, 2, 3])),
        ],
      );
      final names = entries(docx).map((f) => f.name).toList();
      expect(names.any((n) => n.startsWith('word/media/')), isFalse);
    });
  });

  group('image helpers', () {
    test('sniffs formats by magic bytes', () {
      expect(sniffImageFormat(_pngBytes()), ImageFormat.png);
      expect(
        sniffImageFormat(Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xE0])),
        ImageFormat.jpeg,
      );
      expect(
        sniffImageFormat(
          Uint8List.fromList([0x47, 0x49, 0x46, 0x38, 0x39, 0x61]),
        ),
        ImageFormat.gif,
      );
      expect(
        sniffImageFormat(
          Uint8List.fromList([
            0x52,
            0x49,
            0x46,
            0x46,
            0,
            0,
            0,
            0,
            0x57,
            0x45,
            0x42,
            0x50,
          ]),
        ),
        ImageFormat.webp,
      );
      expect(sniffImageFormat(Uint8List.fromList([9, 9, 9])), isNull);
    });

    test('png dimensions come from IHDR', () {
      final (w, h) = imageSize(
        _pngBytes(width: 320, height: 240),
        fallbackWidth: 1,
        fallbackHeight: 1,
      );
      expect(w, 320);
      expect(h, 240);
    });

    test('jpeg SOF scanning finds dimensions', () {
      // APP0 marker then SOF0.
      final jpeg = Uint8List.fromList([
        0xFF, 0xD8, 0xFF, //
        0xE0, 0x00, 0x04, 0x00, 0x00, // APP0 len 4
        0xFF,
        0xC0,
        0x00,
        0x0B,
        0x08,
        0x00,
        0x96,
        0x01,
        0x40, // SOF0 h=150 w=320
        0x01, 0x01, 0x11, 0x00,
      ]);
      final (w, h) = imageSize(jpeg, fallbackWidth: 1, fallbackHeight: 1);
      expect(w, 320);
      expect(h, 150);
    });
  });
}

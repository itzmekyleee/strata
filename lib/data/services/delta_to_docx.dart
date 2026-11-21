import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_quill/flutter_quill.dart';

import '../models/note.dart';
import 'attachment_storage.dart';
import 'note_blocks.dart';

/// Exports a note to .docx (WordprocessingML) using the shared block IR.
/// Produces a minimal, valid OPC package: no styles.xml, direct
/// formatting only, literal list markers, bordered tables.
class DeltaToDocxConverter {
  DeltaToDocxConverter(this.storage);

  final AttachmentStorage storage;

  Future<Uint8List> exportNote(
    Note note, {
    double lineHeight = 1.55,
    double paraSpacing = 4.0,
  }) async {
    final blocks = documentToBlocks(
      Document.fromJson(
        jsonDecode(note.contentDelta.isEmpty ? '[]' : note.contentDelta)
            as List,
      ),
      resolveImage: _readImageBytes,
    );
    return buildDocx(
      title: note.title.trim(),
      blocks: blocks,
      lineHeight: lineHeight,
      paraSpacing: paraSpacing,
    );
  }

  Uint8List? _readImageBytes(String source) {
    try {
      if (source.startsWith('data:image')) {
        final b64 = source.split(',').last;
        return base64Decode(b64);
      }
      final file = storage.resolveEmbedSource(source);
      if (file != null) {
        return File(file.path).readAsBytesSync();
      }
    } catch (_) {}
    return null;
  }
}

/// Pure DOCX builder — testable without IO.
Uint8List buildDocx({
  required String title,
  required List<NoteBlock> blocks,
  double lineHeight = 1.55,
  double paraSpacing = 4.0,
}) {
  // Resolve every image block up-front so unsupported formats are skipped
  // without breaking block↔image alignment.
  var imageIndex = 0;
  final media = <(String, String, Uint8List)>[]; // (filename, relId, bytes)
  final body = StringBuffer();

  void writeImage(ImageBlock block) {
    final fmt = sniffImageFormat(block.bytes);
    if (fmt == null) return;
    final relId = 'rId${100 + imageIndex}';
    final ext = switch (fmt) {
      ImageFormat.png => 'png',
      ImageFormat.jpeg => 'jpg',
      ImageFormat.gif => 'gif',
      ImageFormat.webp => 'webp',
    };
    final name = 'image${imageIndex + 1}.$ext';
    imageIndex++;
    media.add((name, relId, block.bytes));

    // Fit within ~6.2" text column at 96 dpi.
    const maxPx = 595.0;
    final dims = imageSize(
      block.bytes,
      fallbackWidth: 480,
      fallbackHeight: 320,
    );
    double w = dims.$1.toDouble();
    double h = dims.$2.toDouble();
    if (w > maxPx) {
      h *= maxPx / w;
      w = maxPx;
    }
    final cx = (w * 9525).round();
    final cy = (h * 9525).round();

    body.write(
      '<w:p><w:pPr><w:jc w:val="center"/></w:pPr><w:r><w:drawing>'
      '<wp:inline distT="0" distB="0" distL="0" distR="0" '
      'xmlns:wp="http://schemas.openxmlformats.org/drawingml/2006/wordprocessingDrawing">'
      '<wp:extent cx="$cx" cy="$cy"/><wp:effectExtent l="0" t="0" r="0" b="0"/>'
      '<wp:docPr id="$imageIndex" name="Picture $imageIndex"/>'
      '<a:graphic xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main">'
      '<a:graphicData uri="http://schemas.openxmlformats.org/drawingml/2006/picture">'
      '<pic:pic xmlns:pic="http://schemas.openxmlformats.org/drawingml/2006/picture">'
      '<pic:nvPicPr><pic:cNvPr id="$imageIndex" name="$name"/><pic:cNvPicPr/></pic:nvPicPr>'
      '<pic:blipFill><a:blip r:embed="$relId"/><a:stretch><a:fillRect/></a:stretch></pic:blipFill>'
      '<pic:spPr><a:xfrm><a:off x="0" y="0"/><a:ext cx="$cx" cy="$cy"/></a:xfrm>'
      '<a:prstGeom prst="rect"><a:avLst/></a:prstGeom></pic:spPr>'
      '</pic:pic></a:graphicData></a:graphic></wp:inline></w:drawing></w:r></w:p>',
    );
  }

  // Line spacing: 240 twips = single; 1.55 ≈ 372.
  final lineTwips = (lineHeight * 240).round();
  // Paragraph spacing: 1px ≈ 15 twips at 96 DPI / 1440 twips/inch.
  final paraTwips = (paraSpacing * 15).round();

  for (final block in blocks) {
    switch (block) {
      case HeadingBlock(:var level, :var runs):
        body.write(
          _paragraph([
            for (final r in runs)
              _runXml(
                NoteRun(
                  text: r.text,
                  bold: true,
                  italic: r.italic,
                  underline: r.underline,
                  strike: r.strike,
                  color: r.color,
                ),
                sizeHalfPt: switch (level) {
                  1 => 44,
                  2 => 34,
                  _ => 28,
                },
              ),
          ], spacingBefore: (paraTwips * 3.5).round(), lineTwips: lineTwips),
        );
      case ParagraphBlock(:var runs, :var align):
        body.write(_paragraph(runs.map(_runXml), align: align, lineTwips: lineTwips, spacingAfter: paraTwips, spacingBefore: paraTwips));
      case ListItemBlock(:var marker, :var indent, :var runs):
        body.write(_listItem(marker, indent, runs, lineTwips: lineTwips, spacingAfter: paraTwips));
      case TableBlock(:var rows):
        body.write(_table(rows));
      case ImageBlock():
        writeImage(block);
      case DividerBlock():
        body.write(
          '<w:p><w:pPr>'
          '<w:pBdr><w:bottom w:val="single" w:sz="6" w:space="1" w:color="9AA3B2"/></w:pBdr>'
          '<w:spacing w:before="120" w:after="120"/>'
          '</w:pPr></w:p>',
        );
    }
  }

  final docXml = _documentXml(title, body.toString());
  final relsXml = _documentRels([for (final (n, _, _) in media) n]);

  final archive = Archive()
    ..addFile(ArchiveFile.string('[Content_Types].xml', _contentTypes()))
    ..addFile(ArchiveFile.string('_rels/.rels', _rootRels()))
    ..addFile(ArchiveFile.string('word/document.xml', docXml))
    ..addFile(ArchiveFile.string('word/_rels/document.xml.rels', relsXml));
  for (final (name, _, bytes) in media) {
    archive.addFile(ArchiveFile.bytes('word/media/$name', bytes));
  }
  return Uint8List.fromList(ZipEncoder().encode(archive));
}

// ---------------------------------------------------------------------------
// XML parts
// ---------------------------------------------------------------------------

String _contentTypes() =>
    '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types"><Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/><Default Extension="xml" ContentType="application/xml"/><Default Extension="png" ContentType="image/png"/><Default Extension="jpg" ContentType="image/jpeg"/><Default Extension="jpeg" ContentType="image/jpeg"/><Default Extension="gif" ContentType="image/gif"/><Default Extension="webp" ContentType="image/webp"/><Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/></Types>''';

String _rootRels() => '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/></Relationships>''';

String _documentRels(List<String> imageNames) {
  final sb = StringBuffer(
    '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>\n'
    '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">',
  );
  for (var i = 0; i < imageNames.length; i++) {
    sb.write(
      '<Relationship Id="rId${100 + i}" '
      'Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/image" '
      'Target="media/${imageNames[i]}"/>',
    );
  }
  sb.write('</Relationships>');
  return sb.toString();
}

String _documentXml(String title, String body) {
  final titleXml = title.isEmpty
      ? ''
      : _paragraph([
          _runXml(NoteRun(text: title, bold: true), sizeHalfPt: 52),
        ], spacingAfter: 240);
  return '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>\n'
      '<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main" '
      'xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">'
      '<w:body>$titleXml$body'
      '<w:sectPr><w:pgSz w:w="11906" w:h="16838"/>'
      '<w:pgMar w:top="1418" w:right="1134" w:bottom="1418" w:left="1134"/></w:sectPr>'
      '</w:body></w:document>';
}

// ---------------------------------------------------------------------------
// Block renderers
// ---------------------------------------------------------------------------

String _paragraph(
  Iterable<String> runs, {
  NoteAlign align = NoteAlign.left,
  int spacingAfter = 80,
  int spacingBefore = 0,
  int lineTwips = 372,
}) {
  final jc = switch (align) {
    NoteAlign.center => '<w:jc w:val="center"/>',
    NoteAlign.right => '<w:jc w:val="right"/>',
    NoteAlign.justify => '<w:jc w:val="both"/>',
    NoteAlign.left => '',
  };
  final props =
      '<w:pPr><w:spacing w:before="$spacingBefore" w:after="$spacingAfter" w:line="$lineTwips" w:lineRule="auto"/>$jc</w:pPr>';
  return '<w:p>$props${runs.join()}</w:p>';
}

String _listItem(String marker, int indent, List<NoteRun> runs, {int spacingAfter = 40, int lineTwips = 372}) {
  // 360 twips per indent step ≈ 0.25".
  final leftTwips = 360 + indent * 360;
  return '<w:p><w:pPr><w:spacing w:before="0" w:after="$spacingAfter" w:line="$lineTwips" w:lineRule="auto"/>'
      '<w:ind w:left="$leftTwips" w:hanging="240"/></w:pPr>'
      '<w:r><w:t xml:space="preserve">${escXml(marker)}</w:t></w:r>'
      '<w:r><w:tab/></w:r>${runs.map(_runXml).join()}</w:p>';
}

String _table(List<List<String>> rows) {
  const border =
      '<w:top w:val="single" w:sz="4" w:color="9AA3B2"/><w:left w:val="single" w:sz="4" w:color="9AA3B2"/><w:bottom w:val="single" w:sz="4" w:color="9AA3B2"/><w:right w:val="single" w:sz="4" w:color="9AA3B2"/><w:insideH w:val="single" w:sz="4" w:color="9AA3B2"/><w:insideV w:val="single" w:sz="4" w:color="9AA3B2"/>';
  final cols = rows.first.length;
  final cellW = (9600 / cols).round();

  String row(List<String> cells, {required bool header}) =>
      '<w:tr>${[for (final c in cells) '<w:tc><w:tcPr><w:tcW w:w="$cellW" w:type="dxa"/>'
            '${header ? '<w:shd w:val="clear" w:fill="F2F4F7"/>' : ''}</w:tcPr>'
            '<w:p><w:pPr><w:spacing w:before="20" w:after="20"/></w:pPr>'
            '${_runXml(NoteRun(text: c, bold: header))}</w:p></w:tc>'].join()}</w:tr>';

  return '<w:tbl><w:tblPr><w:tblW w:w="0" w:type="auto"/>'
      '<w:tblBorders>$border</w:tblBorders></w:tblPr>'
      '${row(rows.first, header: true)}'
      '${rows.skip(1).map((r) => row(r, header: false)).join()}</w:tbl>'
      '<w:p><w:pPr><w:spacing w:after="60"/></w:pPr></w:p>';
}

// ---------------------------------------------------------------------------
// Runs & helpers
// ---------------------------------------------------------------------------

String _runXml(NoteRun run, {int? sizeHalfPt}) {
  if (run.text.isEmpty) return '';
  final rPr = StringBuffer('<w:rPr>');
  if (run.bold) rPr.write('<w:b/>');
  if (run.italic) rPr.write('<w:i/>');
  if (run.strike) rPr.write('<w:strike/>');
  if (run.underline) rPr.write('<w:u w:val="single"/>');
  if (run.code) rPr.write('<w:rFonts w:ascii="Consolas" w:hAnsi="Consolas"/>');
  if (run.color != null) {
    final hex = (run.color! & 0xFFFFFF)
        .toRadixString(16)
        .padLeft(6, '0')
        .toUpperCase();
    rPr.write('<w:color w:val="$hex"/>');
  }
  rPr.write('<w:sz w:val="${sizeHalfPt ?? 22}"/></w:rPr>');
  return '<w:r>$rPr<w:t xml:space="preserve">${escXml(run.text)}</w:t></w:r>';
}

String escXml(String s) => s
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;');

enum ImageFormat { png, jpeg, gif, webp }

/// Sniffs common raster signatures; null when unrecognized.
ImageFormat? sniffImageFormat(Uint8List bytes) {
  if (bytes.length >= 8 &&
      bytes[0] == 0x89 &&
      bytes[1] == 0x50 &&
      bytes[2] == 0x4E &&
      bytes[3] == 0x47) {
    return ImageFormat.png;
  }
  if (bytes.length >= 3 &&
      bytes[0] == 0xFF &&
      bytes[1] == 0xD8 &&
      bytes[2] == 0xFF) {
    return ImageFormat.jpeg;
  }
  if (bytes.length >= 6 &&
      bytes[0] == 0x47 &&
      bytes[1] == 0x49 &&
      bytes[2] == 0x46) {
    return ImageFormat.gif;
  }
  if (bytes.length >= 12 &&
      bytes[0] == 0x52 &&
      bytes[1] == 0x49 &&
      bytes[2] == 0x46 &&
      bytes[3] == 0x46 &&
      bytes[8] == 0x57 &&
      bytes[9] == 0x45 &&
      bytes[10] == 0x42 &&
      bytes[11] == 0x50) {
    return ImageFormat.webp;
  }
  return null;
}

/// Extracts pixel dimensions from PNG IHDR or JPEG SOF markers as
/// (width, height); falls back to the provided defaults.
(int, int) imageSize(
  Uint8List bytes, {
  required int fallbackWidth,
  required int fallbackHeight,
}) {
  try {
    final format = sniffImageFormat(bytes);
    if (format == ImageFormat.png && bytes.length >= 24) {
      final w =
          (bytes[16] << 24) | (bytes[17] << 16) | (bytes[18] << 8) | bytes[19];
      final h =
          (bytes[20] << 24) | (bytes[21] << 16) | (bytes[22] << 8) | bytes[23];
      if (w > 0 && h > 0) return (w, h);
    }
    if (format == ImageFormat.jpeg) {
      var i = 2;
      while (i + 9 < bytes.length) {
        if (bytes[i] != 0xFF) break;
        final marker = bytes[i + 1];
        final len = (bytes[i + 2] << 8) | bytes[i + 3];
        // SOF0..SOF15 except DHT/JPG/DAC carry dimensions.
        if (marker >= 0xC0 &&
            marker <= 0xCF &&
            marker != 0xC4 &&
            marker != 0xC8 &&
            marker != 0xCC) {
          final h = (bytes[i + 5] << 8) | bytes[i + 6];
          final w = (bytes[i + 7] << 8) | bytes[i + 8];
          if (w > 0 && h > 0) return (w, h);
          break;
        }
        i += 2 + len;
      }
    }
  } catch (_) {}
  return (fallbackWidth, fallbackHeight);
}

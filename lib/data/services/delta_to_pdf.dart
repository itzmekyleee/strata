import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_quill/flutter_quill.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../models/note.dart';
import 'attachment_storage.dart';
import 'note_blocks.dart';

class DeltaToPdfConverter {
  DeltaToPdfConverter(this.storage);

  final AttachmentStorage storage;

  late pw.Font _regular;
  late pw.Font _bold;
  late pw.Font _italic;
  late pw.Font _boldItalic;
  bool _loaded = false;

  Future<void> _ensureFonts() async {
    if (_loaded) return;
    Future<pw.Font> load(String path) async =>
        pw.Font.ttf(await rootBundle.load(path));
    _regular = await load('assets/fonts/Inter-Regular.ttf');
    _bold = await load('assets/fonts/Inter-Bold.ttf');
    _italic = await load('assets/fonts/Inter-Italic.ttf');
    try {
      _boldItalic = await load('assets/fonts/Inter-BoldItalic.ttf');
    } catch (_) {
      // The italic-bold face isn't bundled; fall back to bold so exports
      // don't crash on mixed bold+italic runs.
      _boldItalic = _bold;
    }
    _loaded = true;
  }

  static const _bodyBase = PdfColor.fromInt(0xFF0A0A08);

  Future<Uint8List> exportNote(
    Note note, {
    double lineHeight = 1.55,
    double paraSpacing = 4.0,
  }) async {
    await _ensureFonts();
    final doc = pw.Document();
    final blocks = documentToBlocks(
      Document.fromJson(
        jsonDecode(note.contentDelta.isEmpty ? '[]' : note.contentDelta)
            as List,
      ),
      resolveImage: _readImageBytes,
    );
    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.symmetric(horizontal: 48, vertical: 56),
        build: (context) => [
          if (note.title.trim().isNotEmpty)
            pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 18),
              child: pw.Text(
                note.title.trim(),
                style: pw.TextStyle(
                  fontSize: 26,
                  fontWeight: pw.FontWeight.bold,
                  font: _bold,
                ),
              ),
            ),
          ...blocks.map((b) => _blockToWidget(b, lineHeight, paraSpacing)),
        ],
      ),
    );
    return doc.save();
  }

  pw.Widget _blockToWidget(NoteBlock block, double lineHeight, double paraSpacing) => switch (block) {
    HeadingBlock(:var level, :var runs) => pw.Padding(
      padding: pw.EdgeInsets.only(top: paraSpacing + (level == 1 ? 6 : 4), bottom: paraSpacing + 1),
      child: pw.RichText(
        text: pw.TextSpan(
          children: [
            for (final r in runs) _runToSpan(r, _headingStyle(level, r)),
          ],
        ),
      ),
    ),
    ParagraphBlock(:var runs, :var align) => pw.Padding(
      padding: pw.EdgeInsets.only(bottom: paraSpacing),
      child: pw.RichText(
        text: pw.TextSpan(children: [for (final r in runs) _runToSpan(r)]),
        textAlign: switch (align) {
          NoteAlign.center => pw.TextAlign.center,
          NoteAlign.right => pw.TextAlign.right,
          NoteAlign.justify => pw.TextAlign.justify,
          NoteAlign.left => pw.TextAlign.left,
        },
      ),
    ),
    ListItemBlock(:var marker, :var indent, :var runs) => pw.Container(
      margin: pw.EdgeInsets.only(bottom: paraSpacing),
      padding: pw.EdgeInsets.only(left: 16.0 + indent * 18),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(
            width: 18,
            child: pw.Text(
              marker,
              style: pw.TextStyle(fontSize: 11, font: _regular),
            ),
          ),
          pw.Expanded(
            child: pw.RichText(
              text: pw.TextSpan(
                children: [for (final r in runs) _runToSpan(r)],
              ),
            ),
          ),
        ],
      ),
    ),
    TableBlock(:var rows) => pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 6),
      child: pw.TableHelper.fromTextArray(
        headers: rows.first,
        data: rows.skip(1).toList(),
        headerStyle: pw.TextStyle(font: _bold, fontSize: 10),
        cellStyle: pw.TextStyle(font: _regular, fontSize: 10),
        border: pw.TableBorder.all(color: const PdfColor.fromInt(0xFF8A8478)),
      ),
    ),
    ImageBlock(:var bytes) => pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 6),
      child: pw.Center(
        child: pw.Image(
          pw.MemoryImage(bytes),
          width: 320,
          fit: pw.BoxFit.contain,
        ),
      ),
    ),
    DividerBlock() => pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 10),
      child: pw.Divider(
        height: 2,
        thickness: 0.8,
        color: const PdfColor.fromInt(0xFF8A8478),
      ),
    ),
  };

  pw.TextStyle _headingStyle(int level, NoteRun run) {
    final size = switch (level) {
      1 => 22.0,
      2 => 17.0,
      _ => 14.0,
    };
    return pw.TextStyle(
      font: run.italic ? _italic : _bold,
      fontSize: size,
      color: run.color != null ? PdfColor.fromInt(run.color!) : _bodyBase,
    );
  }

  pw.TextSpan _runToSpan(NoteRun run, [pw.TextStyle? style]) {
    style ??= pw.TextStyle(fontSize: 11, font: _regular, color: _bodyBase);
    if (run.bold && !run.italic) {
      style = style.copyWith(font: _bold);
    } else if (run.italic && !run.bold) {
      style = style.copyWith(font: _italic);
    } else if (run.bold && run.italic) {
      style = style.copyWith(font: _boldItalic);
    }
    if (run.color != null) {
      style = style.copyWith(color: PdfColor.fromInt(run.color!));
    }
    if (run.underline) {
      style = style.copyWith(
        decoration: pw.TextDecoration.underline,
        decorationStyle: pw.TextDecorationStyle.solid,
      );
    }
    return pw.TextSpan(text: run.text, style: style);
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

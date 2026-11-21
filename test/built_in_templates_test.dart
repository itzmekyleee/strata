import 'dart:convert';

import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:strata/data/services/built_in_templates.dart';
import 'package:strata/data/services/table_embed.dart';

void main() {
  test('every built-in template decodes as a valid quill document', () {
    expect(BuiltinTemplates.all, isNotEmpty);
    for (final t in BuiltinTemplates.all) {
      final ops = jsonDecode(t.deltaJson) as List<dynamic>;
      final doc = Document.fromJson(ops);
      expect(
        doc.toPlainText(),
        isNotNull,
        reason: '${t.name} produced an invalid document',
      );
    }
  });

  test('reading list template contains a parsable 4x4 table', () {
    final reading = BuiltinTemplates.all.firstWhere(
      (t) => t.name == 'Reading list',
    );
    final doc = Document.fromJson(jsonDecode(reading.deltaJson) as List);
    final tableOps = <String>[];
    for (final node in doc.root.children) {
      if (node is Line) {
        for (final child in node.children) {
          if (child is Embed &&
              child.value.type == StrataTableEmbed.tableType) {
            tableOps.add(child.value.data.toString());
          }
        }
      }
    }
    expect(tableOps, hasLength(1));
    final cells = StrataTableEmbed.parse(tableOps.first);
    expect(cells.length, 4);
    expect(cells.every((r) => r.length == 4), isTrue);
    expect(cells.first, ['Title', 'Author', 'Status', 'Notes']);
  });
}

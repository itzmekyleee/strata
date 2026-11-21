import 'dart:convert';

import 'package:flutter_quill/flutter_quill.dart';

class StrataTableEmbed extends CustomBlockEmbed {
  const StrataTableEmbed(super.type, super.data);

  static const String tableType = 'table';

  static StrataTableEmbed fromCells(List<List<String>> cells) {
    final cols = cells.fold<int>(
      0,
      (max, row) => row.length > max ? row.length : max,
    );
    final flat = <String>[
      for (final row in cells)
        for (var c = 0; c < cols; c++) c < row.length ? row[c] : '',
    ];
    return StrataTableEmbed(
      tableType,
      jsonEncode({'cols': cols, 'rows': cells.length, 'cells': flat}),
    );
  }

  static List<List<String>> parse(String data) {
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
      return const [
        ['', ''],
        ['', ''],
      ];
    }
  }
}

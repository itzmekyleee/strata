import 'dart:convert';

import 'package:flutter_quill/flutter_quill.dart';

/// Parses a stored Quill delta JSON string into a [Document].
///
/// Falls back to a fresh empty document when the payload is blank,
/// malformed, or decodes to an empty op list — `Document.fromJson` throws
/// `ArgumentError` on an empty op list (quill documents must end in '\n'),
/// which previously left blank notes stuck on the editor loading spinner.
Document parseNoteDelta(String raw) {
  try {
    final trimmed = raw.trim();
    if (trimmed.isNotEmpty) {
      final decoded = jsonDecode(trimmed);
      if (decoded is List && decoded.isNotEmpty) {
        return Document.fromJson(decoded);
      }
    }
  } catch (_) {
    // Corrupt or partially synced delta: open an empty document instead of
    // bricking the editor.
  }
  return Document();
}

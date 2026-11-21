import 'dart:convert';

abstract final class TextStats {
  static String plainFromDelta(String deltaJson) {
    try {
      final ops = (jsonDecode(deltaJson) as List).cast<Map<String, dynamic>>();
      final buffer = StringBuffer();
      for (final op in ops) {
        final insert = op['insert'];
        if (insert is String) buffer.write(insert);
      }
      return buffer.toString();
    } catch (_) {
      return '';
    }
  }

  static int wordCount(String plainText) {
    final matches = RegExp(r'\S+').allMatches(plainText);
    return matches.length;
  }
}

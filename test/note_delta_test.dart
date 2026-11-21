import 'package:flutter_test/flutter_test.dart';
import 'package:strata/core/utils/note_delta.dart';

void main() {
  group('parseNoteDelta (editor loading regression)', () {
    test('blank delta no longer throws — falls back to empty document', () {
      // Document.fromJson(const []) throws ArgumentError; the parser must
      // survive it so newly created blank notes open in the editor.
      final doc = parseNoteDelta('');
      expect(doc.toPlainText(), '\n');
    });

    test('whitespace-only delta falls back', () {
      expect(parseNoteDelta('   ').toPlainText(), '\n');
    });

    test('empty JSON list falls back', () {
      expect(parseNoteDelta('[]').toPlainText(), '\n');
    });

    test('corrupt JSON falls back instead of throwing', () {
      expect(parseNoteDelta('{not json').toPlainText(), '\n');
    });

    test('valid delta parses with content intact', () {
      final doc = parseNoteDelta('[{"insert":"hello world\\n"}]');
      expect(doc.toPlainText().trim(), 'hello world');
    });

    test('JSON that is not a list falls back', () {
      expect(parseNoteDelta('{"insert":"x"}').toPlainText(), '\n');
    });
  });
}

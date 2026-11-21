import 'package:flutter_test/flutter_test.dart';
import 'package:strata/core/utils/text_stats.dart';

void main() {
  test('wordCount counts whitespace-separated runs', () {
    expect(TextStats.wordCount('hello world'), 2);
    expect(TextStats.wordCount('  one   two\tthree\nfour '), 4);
    expect(TextStats.wordCount(''), 0);
    expect(TextStats.wordCount('   '), 0);
    expect(TextStats.wordCount('single'), 1);
  });

  test('plainFromDelta concatenates string inserts only', () {
    const delta =
        '[{"insert":"Hello "},{"insert":{"image":"x.png"}},'
        '{"insert":"world\\n"}]';
    expect(TextStats.plainFromDelta(delta), 'Hello world\n');
  });

  test('plainFromDelta survives malformed json', () {
    expect(TextStats.plainFromDelta('not-json'), '');
  });
}

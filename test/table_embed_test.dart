import 'package:flutter_test/flutter_test.dart';
import 'package:strata/data/services/table_embed.dart';

void main() {
  test('table embed round-trips cells through json', () {
    final embed = StrataTableEmbed.fromCells([
      ['a', 'b'],
      ['c', 'd'],
    ]);
    expect(embed.type, 'table');

    final parsed = StrataTableEmbed.parse(embed.data as String);
    expect(parsed, [
      ['a', 'b'],
      ['c', 'd'],
    ]);
  });

  test('parse falls back to empty grid on garbage data', () {
    final parsed = StrataTableEmbed.parse('garbage');
    expect(parsed.length, 2);
    expect(parsed.first.length, 2);
  });

  test('parse pads missing cells', () {
    final embed = StrataTableEmbed.fromCells([
      ['x'],
      ['', ''],
    ]);
    final map = (embed.data as String); // json string; decode via parse
    final parsed = StrataTableEmbed.parse(map);
    expect(parsed[0].length, 2);
    expect(parsed[0][0], 'x');
    expect(parsed[1].length, 2);
  });
}

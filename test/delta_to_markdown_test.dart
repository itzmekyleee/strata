import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:strata/data/services/delta_to_markdown.dart';
import 'package:strata/data/services/table_embed.dart';

String deltaOf(List<Map<String, dynamic>> ops) => jsonEncode(ops);

Map<String, dynamic> text(String insert, [Map<String, dynamic>? attrs]) => {
  'insert': insert,
  'attributes': ?attrs,
};

void main() {
  test('empty delta produces empty string', () {
    expect(DeltaToMarkdown.convert(''), '');
  });

  test('title becomes h1', () {
    final md = DeltaToMarkdown.convert(
      '[{"insert":"body\\n"}]',
      title: 'My note',
    );
    expect(md, '# My note\nbody\n');
  });

  test('headings map to # levels', () {
    final md = DeltaToMarkdown.convert(
      deltaOf([
        text('One'),
        {
          'attributes': {'header': 1},
          'insert': '\n',
        },
        text('Two'),
        {
          'attributes': {'header': 2},
          'insert': '\n',
        },
        text('Three'),
        {
          'attributes': {'header': 3},
          'insert': '\n',
        },
      ]),
    );
    expect(md, '# One\n## Two\n### Three\n');
  });

  test('bold, italic, strike and inline code', () {
    final md = DeltaToMarkdown.convert(
      deltaOf([
        text('bold', {'bold': true}),
        {'insert': ' and '},
        text('italic', {'italic': true}),
        {'insert': ' and '},
        text('gone', {'strike': true}),
        {'insert': ' and '},
        text('code', {'code': true}),
        {'insert': '\n'},
      ]),
    );
    expect(md, '**bold** and _italic_ and ~~gone~~ and `code`\n');
  });

  test('links wrap escaped text', () {
    final md = DeltaToMarkdown.convert(
      deltaOf([
        text('go [here]', {'link': 'https://example.com'}),
        {'insert': '\n'},
      ]),
    );
    expect(md, '[go \\[here\\]](https://example.com)\n');
  });

  test('bullet and ordered lists with indent', () {
    final md = DeltaToMarkdown.convert(
      deltaOf([
        text('a'),
        {
          'attributes': {'list': 'bullet'},
          'insert': '\n',
        },
        text('b'),
        {
          'attributes': {'list': 'ordered'},
          'insert': '\n',
        },
        text('c'),
        {
          'attributes': {'list': 'ordered', 'indent': 1},
          'insert': '\n',
        },
        text('plain'),
        {'insert': '\n'},
        text('d'),
        {
          'attributes': {'list': 'ordered'},
          'insert': '\n',
        },
        text('e'),
        {
          'attributes': {'list': 'ordered'},
          'insert': '\n',
        },
      ]),
    );
    // Quill groups contiguous same-style lines into blocks; a style change,
    // indent change or intervening paragraph starts a new block, so each
    // ordered run restarts at 1 (standard GFM nested-sublist behavior).
    expect(md, '- a\n1. b\n  1. c\nplain\n1. d\n2. e\n');
  });

  test('blockquote prefixes lines', () {
    final md = DeltaToMarkdown.convert(
      deltaOf([
        text('wise words'),
        {
          'attributes': {'blockquote': true},
          'insert': '\n',
        },
      ]),
    );
    expect(md, '> wise words\n');
  });

  test('image renders relative file name', () {
    final md = DeltaToMarkdown.convert(
      deltaOf([
        {
          'insert': {'image': 'embeds/abc123.png'},
        },
        {'insert': '\n'},
      ]),
    );
    expect(md, '![image](abc123.png)\n\n');
  });

  test('table embed renders GFM with escaped pipes', () {
    final embed = StrataTableEmbed.fromCells([
      ['Name | Role', 'Notes'],
      ['Ada', 'pioneer'],
    ]);
    final md = DeltaToMarkdown.convert(
      deltaOf([
        {
          'insert': {'table': embed.data},
        },
        {'insert': '\n'},
      ]),
    );
    expect(
      md,
      // Trailing blank line comes from the delta's line terminator after
      // the embed; valid GFM.
      '| Name \\| Role | Notes |\n'
      '| --- | --- |\n'
      '| Ada | pioneer |\n\n',
    );
  });

  test('corrupt json yields empty string instead of throwing', () {
    expect(DeltaToMarkdown.convert('{not json'), '');
  });
}

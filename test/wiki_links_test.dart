import 'package:flutter_test/flutter_test.dart';
import 'package:strata/core/utils/wiki_links.dart';

void main() {
  group('WikiLinks.extractTitles', () {
    test('finds all titles in order', () {
      final titles = WikiLinks.extractTitles('see [[Groceries]] and [[Ideas]]');
      expect(titles, ['Groceries', 'Ideas']);
    });

    test('preserves duplicates', () {
      expect(WikiLinks.extractTitles('[[A]] [[A]]'), ['A', 'A']);
    });

    test('trims inner whitespace and drops blank tokens', () {
      expect(WikiLinks.extractTitles('[[  Spaced  ]] [[]]'), ['Spaced']);
    });

    test('ignores single brackets and nested brackets', () {
      expect(WikiLinks.extractTitles('[not] a [[real]] [link]'), ['real']);
      expect(WikiLinks.extractTitles('[[a[b]]'), isEmpty);
    });

    test('does not cross newlines', () {
      expect(WikiLinks.extractTitles('[[one\ntwo]]'), isEmpty);
      expect(WikiLinks.extractTitles('[[first]]\n[[second]]'), [
        'first',
        'second',
      ]);
    });
  });

  group('WikiLinks.completeTokens', () {
    test('reports exact ranges including brackets', () {
      const text = 'hello [[World]]!';
      final tokens = WikiLinks.completeTokens(text);
      expect(tokens, hasLength(1));
      expect(tokens.single.start, 6);
      expect(tokens.single.end, 15);
      expect(tokens.single.title, 'World');
      expect(text.substring(6, 15), '[[World]]');
    });
  });

  group('WikiLinks.detectQuery', () {
    test('detects an open fragment with typed query', () {
      const text = 'note about [[proj';
      final q = WikiLinks.detectQuery(text, text.length);
      expect(q, isNotNull);
      expect(q!.startIndex, 11);
      expect(q.query, 'proj');
    });

    test('detects with empty query right after [[', () {
      const text = 'abc [[';
      final q = WikiLinks.detectQuery(text, text.length);
      expect(q!.startIndex, 4);
      expect(q.query, '');
    });

    test('null once the token is closed', () {
      const text = '[[done]]';
      expect(WikiLinks.detectQuery(text, text.length), isNull);
    });

    test('null when caret sits before the opening [[', () {
      const text = '[[query';
      expect(WikiLinks.detectQuery(text, 0), isNull);
    });

    test('null across newline', () {
      const text = '[[line\nbreak';
      expect(WikiLinks.detectQuery(text, text.length), isNull);
    });

    test('only the last unclosed [[ wins', () {
      const text = '[[old [[new';
      final q = WikiLinks.detectQuery(text, text.length);
      expect(q!.startIndex, 6);
      expect(q.query, 'new');
    });

    test('caret bounds are safe', () {
      expect(WikiLinks.detectQuery('', 0), isNull);
      expect(WikiLinks.detectQuery('', -1), isNull);
      expect(WikiLinks.detectQuery('', 1), isNull);
    });
  });
}

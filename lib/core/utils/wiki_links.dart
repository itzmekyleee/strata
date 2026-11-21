/// Pure helpers for the `[[wiki link]]` convention stored as literal text
/// inside note deltas.
abstract final class WikiLinks {
  static final _token = RegExp(r'\[\[([^\[\]\n]+)\]\]');
  static final _openToken = RegExp(r'\[\[([^\[\]\n]*)$');

  /// All link titles appearing in [plain], in order of appearance.
  /// Duplicates are preserved; callers dedupe as needed.
  static List<String> extractTitles(String plain) => [
        for (final m in _token.allMatches(plain)) m.group(1)!.trim(),
      ].where((t) => t.isNotEmpty).toList();

  /// Character ranges ([start, end)) of complete `[[title]]` tokens.
  static List<WikiToken> completeTokens(String plain) => [
        for (final m in _token.allMatches(plain))
          if ((m.group(1) ?? '').trim().isNotEmpty)
            WikiToken(
              start: m.start,
              end: m.end,
              title: m.group(1)!.trim(),
            ),
      ];

  /// If the caret sits inside an open `[[query` fragment, returns it so an
  /// autocomplete popup can be shown; null otherwise.
  ///
  /// Rules:
  /// - The fragment must start at the last un-closed `[[`.
  /// - No newline may appear between `[[` and the caret.
  /// - A closing `]]` before the caret means the token is finished → null.
  static WikiQuery? detectQuery(String plain, int caret) {
    if (caret < 0 || caret > plain.length) return null;
    final head = plain.substring(0, caret);
    final match = _openToken.firstMatch(head);
    if (match == null) return null;
    return WikiQuery(
      startIndex: match.start,
      query: match.group(1)!,
    );
  }
}

class WikiToken {
  const WikiToken({
    required this.start,
    required this.end,
    required this.title,
  });

  /// Index of the first `[` in `[[`.
  final int start;

  /// Index just past the closing `]]`.
  final int end;
  final String title;

  int get length => end - start;
}

class WikiQuery {
  const WikiQuery({required this.startIndex, required this.query});

  /// Index of the first `[` of the opening `[[`.
  final int startIndex;

  /// Text typed after `[[`, possibly empty.
  final String query;
}

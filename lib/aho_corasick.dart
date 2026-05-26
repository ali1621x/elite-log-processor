class AhoCorasick {
  final List<String> _patterns = [];
  final Map<String, RegExp> _regexCache = {};

  void addPatterns(List<String> patterns) {
    _patterns.addAll(patterns);
  }

  void build() {
    for (final pattern in _patterns) {
      _regexCache[pattern] = RegExp(pattern, caseSensitive: false);
    }
  }

  List<Match> search(String text) {
    final matches = <Match>[];
    for (final regex in _regexCache.values) {
      matches.addAll(regex.allMatches(text));
    }
    return matches;
  }

  String replaceAll(String text, String replacement) {
    var result = text;
    for (final regex in _regexCache.values) {
      result = result.replaceAll(regex, replacement);
    }
    return result;
  }
}

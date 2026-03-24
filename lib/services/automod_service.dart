/// Automoderation service with a built-in profanity / slur blacklist.
///
/// Checks blog titles and descriptions at upload time.
/// Uses word-boundary matching to avoid false positives.
class AutomodService {
  AutomodService._();

  /// Standard English profanity / slur blacklist.
  static const List<String> _blacklist = [
    // Profanity
    'fuck', 'shit', 'bitch', 'asshole', 'bastard', 'damn', 'crap',
    'dick', 'piss', 'cunt', 'cock', 'bollocks', 'wanker', 'twat',
    'motherfucker', 'bullshit', 'horseshit', 'dumbass', 'jackass',
    'goddamn', 'dipshit', 'shithead', 'douchebag',
    // Slurs — racial / ethnic
    'nigger', 'nigga', 'chink', 'spic', 'wetback', 'beaner', 'gook',
    'kike', 'honky', 'cracker', 'gringo', 'jap', 'paki', 'raghead',
    'towelhead', 'redskin', 'coon', 'darkie', 'chinaman',
    // Slurs — gender / sexuality
    'faggot', 'fag', 'dyke', 'tranny', 'shemale', 'homo',
    // Slurs — disability
    'retard', 'retarded', 'spaz', 'spastic',
  ];

  /// Pre-compiled patterns for each blacklisted word.
  static final List<RegExp> _patterns = _blacklist
      .map((w) => RegExp(r'\b' + RegExp.escape(w) + r'\b', caseSensitive: false))
      .toList();

  /// Check [text] against the blacklist.
  /// Returns every distinct blacklisted word found (lowercased).
  static List<String> checkContent(String text) {
    if (text.isEmpty) return const [];
    final Set<String> found = {};
    for (int i = 0; i < _patterns.length; i++) {
      if (_patterns[i].hasMatch(text)) {
        found.add(_blacklist[i]);
      }
    }
    return found.toList();
  }

  /// Convenience: check both title and description in one call.
  /// Returns `flagged == true` when at least one blacklisted word is found.
  static ({bool flagged, List<String> matchedWords}) containsBlacklistedWords({
    required String title,
    required String description,
  }) {
    final combined = '$title $description';
    final matches = checkContent(combined);
    return (flagged: matches.isNotEmpty, matchedWords: matches);
  }
}

/// Interface for token estimation. Implementations may be heuristic (default)
/// or precise (external tokenizer libraries).
abstract class TokenCounter {
  /// Estimate number of tokens for given text.
  int estimateTokens(String text);
}

/// Default heuristic token counter used by the library.
///
/// This implementation is dependency-free and fast. It produces deterministic
/// estimates by normalizing whitespace and dividing character count by
/// [charsPerToken]. Consumers may replace this with a precise tokenizer.
class HeuristicTokenCounter implements TokenCounter {
  final int charsPerToken;

  HeuristicTokenCounter({this.charsPerToken = 4}) : assert(charsPerToken > 0);

  @override
  int estimateTokens(String text) {
    if (text.isEmpty) return 0;
    // Normalize whitespace and count characters to produce a deterministic estimate.
    final normalized = text.replaceAll(RegExp(r"\s+"), ' ');
    final chars = normalized.length;
    return (chars / charsPerToken).ceil();
  }
}

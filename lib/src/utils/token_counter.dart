/// TokenCounter interface and a simple heuristic implementation.
abstract class TokenCounter {
  /// Estimate number of tokens for given text.
  int estimateTokens(String text);
}

/// Heuristic token counter: estimates tokens by dividing character count by 4.
class HeuristicTokenCounter implements TokenCounter {
  final int charsPerToken;

  HeuristicTokenCounter({this.charsPerToken = 4});

  @override
  int estimateTokens(String text) {
    if (text.isEmpty) return 0;
    final normalized = text.replaceAll(RegExp('\s+'), ' ');
    final chars = normalized.length;
    return (chars / charsPerToken).ceil();
  }
}

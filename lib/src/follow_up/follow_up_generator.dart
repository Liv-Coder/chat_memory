import '../models/message.dart';

/// Pluggable interface for generating contextual follow-up questions
abstract class FollowUpGenerator {
  /// Generate up to [max] follow-up questions given the conversation [messages].
  Future<List<String>> generate(List<Message> messages, {int max = 3});
}

/// Simple heuristic follow-up generator that creates clarifying / next-step
/// prompts using the last user message and the most recent assistant reply.
///
/// This is intentionally small and deterministic so it works without network
/// calls; replace with an AI-backed generator for smarter suggestions.
class HeuristicFollowUpGenerator implements FollowUpGenerator {
  final int maxQuestions;

  HeuristicFollowUpGenerator({this.maxQuestions = 3});

  @override
  Future<List<String>> generate(List<Message> messages, {int max = 3}) async {
    final effectiveMax = max.clamp(1, maxQuestions);

    // Find last user and assistant messages
    Message? lastUser;
    Message? lastAssistant;
    for (var i = messages.length - 1; i >= 0; i--) {
      final m = messages[i];
      if (lastAssistant == null && m.role == MessageRole.assistant) {
        lastAssistant = m;
      }
      if (lastUser == null && m.role == MessageRole.user) {
        lastUser = m;
      }
      if (lastUser != null && lastAssistant != null) break;
    }

    final suggestions = <String>[];

    String snippet(String? s, [int limit = 80]) {
      if (s == null || s.trim().isEmpty) return '';
      final single = s.replaceAll(RegExp(r'\s+'), ' ').trim();
      if (single.length <= limit) return single;
      return '${single.substring(0, limit).trim()}…';
    }

    if (lastUser != null) {
      final userSnippet = snippet(lastUser.content, 60);
      if (userSnippet.isNotEmpty) {
        suggestions.add("Do you mean \"$userSnippet\" or something else?");
      }
    }

    if (lastAssistant != null) {
      final assistantSnippet = snippet(lastAssistant.content, 80);
      if (assistantSnippet.isNotEmpty) {
        suggestions.add(
          "Would you like more detail on this suggestion: \"$assistantSnippet\"?",
        );
      }
    }

    // Generic next-step suggestions
    suggestions.addAll([
      'Would you like a step-by-step plan to accomplish that?',
      'Should I provide examples or code snippets for this topic?',
      'Do you want to save this topic as a memory for future reference?',
    ]);

    // Deduplicate and trim to requested max
    final dedup = <String>{};
    final out = <String>[];
    for (var s in suggestions) {
      if (dedup.add(s)) {
        out.add(s);
        if (out.length >= effectiveMax) break;
      }
    }

    return out;
  }
}

import '../../core/models/message.dart';
import 'context_analyzer.dart';

/// Pluggable interface for generating contextual follow-up questions
abstract class FollowUpGenerator {
  /// Generate up to [max] follow-up questions given the conversation [messages].
  Future<List<String>> generate(List<Message> messages, {int max = 3});
}

/// Enhanced heuristic follow-up generator that uses conversation context analysis
/// to provide more intelligent and contextually relevant suggestions.
///
/// This implementation integrates with ContextAnalyzer to understand conversation
/// flow, topics, sentiment, and user engagement patterns while maintaining
/// deterministic behavior and reliability for fallback scenarios.
class HeuristicFollowUpGenerator implements FollowUpGenerator {
  final int maxQuestions;
  final ContextAnalyzer _contextAnalyzer;

  // Enhanced template categories for different conversation contexts
  static const Map<ConversationStage, List<String>> _stageTemplates = {
    ConversationStage.opening: [
      'What specific aspect would you like to explore first?',
      'Can you tell me more about your goals with this?',
      'What is your experience level with this topic?',
      'Are there any particular constraints or requirements?',
      'What outcome are you hoping to achieve?',
    ],
    ConversationStage.development: [
      'Would you like me to elaborate on any particular point?',
      'Should we dive deeper into this area?',
      'Are there related topics you would like to explore?',
      'How does this fit with your overall objectives?',
      'Would examples or case studies be helpful?',
    ],
    ConversationStage.clarification: [
      'Which part would you like me to clarify further?',
      'Can you tell me what specific aspect is unclear?',
      'Would a different explanation approach help?',
      'Should I provide more context or background?',
      'Would step-by-step guidance be useful?',
    ],
    ConversationStage.closing: [
      'Is there anything else you would like to know about this?',
      'Are there any final questions or concerns?',
      'Would you like a summary of what we have covered?',
      'Is there anything we should review or revisit?',
      'How can I help you implement this?',
    ],
  };

  static const Map<MessageType, List<String>> _typeTemplates = {
    MessageType.question: [
      'Would you like more detail on this aspect?',
      'Are there related questions you have?',
      'Should I explain the reasoning behind this?',
      'Would you like to see different approaches?',
    ],
    MessageType.request: [
      'Would you like me to break this down into steps?',
      'Should I provide examples for each part?',
      'Are there specific requirements I should consider?',
      'Would you like alternative approaches?',
    ],
    MessageType.statement: [
      'How does this align with your expectations?',
      'Would you like to explore this further?',
      'Are there implications we should discuss?',
      'Should we consider other perspectives?',
    ],
    MessageType.clarification: [
      'Does this explanation help clarify things?',
      'Would a concrete example be useful?',
      'Should I explain any other related concepts?',
      'Are there other areas that need clarification?',
    ],
  };

  static const Map<String, List<String>> _sentimentTemplates = {
    'positive': [
      'Would you like to build on this success?',
      'How can we expand on this approach?',
      'Should we explore advanced applications?',
      'What other areas interest you?',
    ],
    'negative': [
      'What specific challenges are you facing?',
      'Would a different approach be more suitable?',
      'Should we try a simpler starting point?',
      'How can I better address your concerns?',
    ],
    'neutral': [
      'Would you like to explore this topic further?',
      'Are there specific aspects that interest you?',
      'Should we consider practical applications?',
      'How does this relate to your needs?',
    ],
  };

  HeuristicFollowUpGenerator({
    this.maxQuestions = 3,
    ContextAnalyzer? contextAnalyzer,
  }) : _contextAnalyzer = contextAnalyzer ?? ContextAnalyzer();

  @override
  Future<List<String>> generate(List<Message> messages, {int max = 3}) async {
    final effectiveMax = max.clamp(1, maxQuestions);

    if (messages.isEmpty) {
      return _getGenericSuggestions(effectiveMax);
    }

    // Analyze conversation context
    final context = await _contextAnalyzer.analyzeContext(messages);

    final suggestions = <String>[];
    final scores = <String, double>{};

    // Generate context-aware suggestions from last messages
    await _addContextualSuggestions(messages, context, suggestions, scores);

    // Add stage-specific suggestions
    _addStageSuggestions(context, suggestions, scores);

    // Add message type-specific suggestions
    _addTypeSuggestions(context, suggestions, scores);

    // Add sentiment-aware suggestions
    _addSentimentSuggestions(context, suggestions, scores);

    // Add topic-aware suggestions
    _addTopicSuggestions(context, suggestions, scores);

    // Add fallback suggestions if needed
    if (suggestions.length < effectiveMax) {
      _addFallbackSuggestions(suggestions, scores);
    }

    // Sort by score and deduplicate
    return _rankAndDeduplicate(suggestions, scores, effectiveMax);
  }

  /// Generate context-aware suggestions based on recent message content
  Future<void> _addContextualSuggestions(
    List<Message> messages,
    ConversationContext context,
    List<String> suggestions,
    Map<String, double> scores,
  ) async {
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

    String snippet(String? s, [int limit = 80]) {
      if (s == null || s.trim().isEmpty) return '';
      final single = s.replaceAll(RegExp(r'\s+'), ' ').trim();
      if (single.length <= limit) return single;
      return '${single.substring(0, limit).trim()}…';
    }

    // Context-aware user message suggestions
    if (lastUser != null) {
      final userSnippet = snippet(lastUser.content, 60);
      if (userSnippet.isNotEmpty) {
        final suggestion = _buildUserContextSuggestion(userSnippet, context);
        suggestions.add(suggestion);
        scores[suggestion] = 0.8 + (context.engagementLevel * 0.2);
      }
    }

    // Context-aware assistant message suggestions
    if (lastAssistant != null) {
      final assistantSnippet = snippet(lastAssistant.content, 80);
      if (assistantSnippet.isNotEmpty) {
        final suggestion = _buildAssistantContextSuggestion(
          assistantSnippet,
          context,
        );
        suggestions.add(suggestion);
        scores[suggestion] = 0.7 + (context.momentum * 0.3);
      }
    }
  }

  /// Build context-aware suggestion for user message
  String _buildUserContextSuggestion(
    String snippet,
    ConversationContext context,
  ) {
    switch (context.lastMessageType) {
      case MessageType.question:
        return 'Would you like me to expand on "$snippet"?';
      case MessageType.request:
        return 'Should I provide more details for "$snippet"?';
      case MessageType.clarification:
        return 'Does my response about "$snippet" address your question?';
      default:
        return 'Do you mean "$snippet" or something else?';
    }
  }

  /// Build context-aware suggestion for assistant message
  String _buildAssistantContextSuggestion(
    String snippet,
    ConversationContext context,
  ) {
    if (context.dominantSentiment == 'negative') {
      return 'Would a different approach work better than "$snippet"?';
    } else if (context.momentum > 0.7) {
      return 'Should we build further on "$snippet"?';
    } else {
      return 'Would you like more detail on "$snippet"?';
    }
  }

  /// Add suggestions based on conversation stage
  void _addStageSuggestions(
    ConversationContext context,
    List<String> suggestions,
    Map<String, double> scores,
  ) {
    final stageTemplates = _stageTemplates[context.stage] ?? [];
    for (var i = 0; i < stageTemplates.length && i < 2; i++) {
      final template = stageTemplates[i];
      suggestions.add(template);
      scores[template] = 0.6 + (context.engagementLevel * 0.2);
    }
  }

  /// Add suggestions based on last message type
  void _addTypeSuggestions(
    ConversationContext context,
    List<String> suggestions,
    Map<String, double> scores,
  ) {
    final typeTemplates = _typeTemplates[context.lastMessageType] ?? [];
    if (typeTemplates.isNotEmpty) {
      final template = typeTemplates.first;
      suggestions.add(template);
      scores[template] = 0.5 + (context.momentum * 0.3);
    }
  }

  /// Add suggestions based on sentiment
  void _addSentimentSuggestions(
    ConversationContext context,
    List<String> suggestions,
    Map<String, double> scores,
  ) {
    if (context.dominantSentiment != null) {
      final sentimentTemplates =
          _sentimentTemplates[context.dominantSentiment!] ?? [];
      if (sentimentTemplates.isNotEmpty) {
        final template = sentimentTemplates.first;
        suggestions.add(template);
        scores[template] = 0.4 + (context.engagementLevel * 0.3);
      }
    }
  }

  /// Add suggestions based on detected topics
  void _addTopicSuggestions(
    ConversationContext context,
    List<String> suggestions,
    Map<String, double> scores,
  ) {
    if (context.topics.isNotEmpty) {
      final primaryTopic = context.topics.first;
      final suggestion = 'Would you like to explore more about $primaryTopic?';
      suggestions.add(suggestion);
      scores[suggestion] =
          0.3 + (context.topicScores[primaryTopic] ?? 0.0) * 0.4;
    }
  }

  /// Add fallback suggestions when not enough context-specific ones
  void _addFallbackSuggestions(
    List<String> suggestions,
    Map<String, double> scores,
  ) {
    final fallbackSuggestions = [
      'Would you like a step-by-step plan to accomplish that?',
      'Should I provide examples or code snippets for this topic?',
      'Can you tell me more about your specific use case?',
      'Would you like me to explain the pros and cons?',
      'Should we explore alternative approaches?',
      'Do you need help with implementation details?',
      'Would you like me to break this down into smaller parts?',
      'Should I provide some practical examples?',
      'Is there a specific aspect you would like to focus on?',
      'Would you like to discuss potential challenges?',
    ];

    fallbackSuggestions.shuffle();
    for (final suggestion in fallbackSuggestions) {
      if (!suggestions.contains(suggestion)) {
        suggestions.add(suggestion);
        scores[suggestion] = 0.2;
      }
    }
  }

  /// Get generic suggestions for empty conversation
  List<String> _getGenericSuggestions(int max) {
    final generic = [
      'What would you like to know?',
      'How can I help you today?',
      'What topic interests you?',
      'What would you like to explore?',
      'Is there something specific you need help with?',
    ];
    generic.shuffle();
    return generic.take(max).toList();
  }

  /// Rank suggestions by score and remove duplicates
  List<String> _rankAndDeduplicate(
    List<String> suggestions,
    Map<String, double> scores,
    int max,
  ) {
    // Remove duplicates while preserving order
    final unique = <String>{};
    final deduped = <String>[];

    for (final suggestion in suggestions) {
      if (unique.add(suggestion)) {
        deduped.add(suggestion);
      }
    }

    // Sort by score (descending)
    deduped.sort((a, b) {
      final scoreA = scores[a] ?? 0.0;
      final scoreB = scores[b] ?? 0.0;
      return scoreB.compareTo(scoreA);
    });

    return deduped.take(max).toList();
  }
}

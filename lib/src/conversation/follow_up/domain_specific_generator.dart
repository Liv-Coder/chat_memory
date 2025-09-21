import '../../core/models/message.dart';
import '../../core/logging/chat_memory_logger.dart';
import 'follow_up_generator.dart';
import 'context_analyzer.dart';

/// Domain-specific template for follow-up generation
class DomainTemplate {
  final String domain;
  final List<String> keywords;
  final Map<ConversationStage, List<String>> stageTemplates;

  const DomainTemplate({
    required this.domain,
    required this.keywords,
    required this.stageTemplates,
  });
}

/// Domain-specific follow-up generator with template system
class DomainSpecificGenerator implements FollowUpGenerator {
  static final _logger = ChatMemoryLogger.loggerFor(
    'domain_specific_generator',
  );

  final List<DomainTemplate> _templates;
  final ContextAnalyzer _contextAnalyzer;
  final double _keywordThreshold;

  // Built-in domain templates
  static final _builtInTemplates = <DomainTemplate>[
    DomainTemplate(
      domain: 'education',
      keywords: ['learn', 'study', 'understand', 'explain', 'teach'],
      stageTemplates: {
        ConversationStage.opening: [
          'What is your current understanding of this topic?',
          'What learning goals do you have?',
        ],
        ConversationStage.development: [
          'Would you like to see examples of this concept?',
          'How does this relate to what you know?',
        ],
        ConversationStage.clarification: [
          'Which part needs more clarification?',
          'Would a different approach help?',
        ],
        ConversationStage.closing: [
          'How confident do you feel about this now?',
          'What would you like to study next?',
        ],
      },
    ),

    DomainTemplate(
      domain: 'technical',
      keywords: ['error', 'bug', 'fix', 'troubleshoot', 'code'],
      stageTemplates: {
        ConversationStage.opening: [
          'Can you describe the specific error?',
          'What were you trying to accomplish?',
        ],
        ConversationStage.development: [
          'Have you tried any troubleshooting steps?',
          'Should we examine the error logs?',
        ],
        ConversationStage.clarification: [
          'Can you provide more details about the error?',
          'What exactly happens when you try this?',
        ],
        ConversationStage.closing: [
          'Did this solution resolve your issue?',
          'Are there any other related problems?',
        ],
      },
    ),

    DomainTemplate(
      domain: 'business',
      keywords: ['strategy', 'plan', 'market', 'revenue', 'business'],
      stageTemplates: {
        ConversationStage.opening: [
          'What are your primary business objectives?',
          'What challenges are you facing?',
        ],
        ConversationStage.development: [
          'What resources do you have available?',
          'How would you measure success?',
        ],
        ConversationStage.clarification: [
          'What metrics are most important to you?',
          'How does this align with your goals?',
        ],
        ConversationStage.closing: [
          'What are the next steps for implementation?',
          'How will you track progress?',
        ],
      },
    ),
  ];

  DomainSpecificGenerator({
    List<DomainTemplate>? templates,
    ContextAnalyzer? contextAnalyzer,
    double keywordThreshold = 0.3,
  }) : _templates = templates ?? _builtInTemplates,
       _contextAnalyzer = contextAnalyzer ?? ContextAnalyzer(),
       _keywordThreshold = keywordThreshold;

  @override
  Future<List<String>> generate(List<Message> messages, {int max = 3}) async {
    final sw = ChatMemoryLogger.logOperationStart(_logger, 'generate');

    try {
      if (messages.isEmpty) {
        return ['What domain are you interested in?', 'How can I help you?'];
      }

      final context = await _contextAnalyzer.analyzeContext(messages);
      final domain = _detectDomain(messages, context);
      final suggestions = _generateSuggestions(domain, context, max);

      ChatMemoryLogger.logOperationEnd(_logger, 'generate', sw);
      return suggestions;
    } catch (error, stackTrace) {
      ChatMemoryLogger.logError(
        _logger,
        'generate',
        error,
        stackTrace: stackTrace,
      );
      return _getFallbackSuggestions(max);
    }
  }

  /// Detect applicable domain based on conversation content
  DomainTemplate? _detectDomain(
    List<Message> messages,
    ConversationContext context,
  ) {
    final allText = messages.map((m) => m.content.toLowerCase()).join(' ');

    for (final template in _templates) {
      final matchedKeywords = template.keywords
          .where((keyword) => allText.contains(keyword))
          .length;

      final score = template.keywords.isNotEmpty
          ? matchedKeywords / template.keywords.length
          : 0.0;

      if (score >= _keywordThreshold) {
        return template;
      }
    }

    return null;
  }

  /// Generate suggestions using domain template
  List<String> _generateSuggestions(
    DomainTemplate? domain,
    ConversationContext context,
    int max,
  ) {
    if (domain == null) {
      return _getFallbackSuggestions(max);
    }

    final stageTemplates = domain.stageTemplates[context.stage] ?? [];
    if (stageTemplates.isEmpty) {
      return _getFallbackSuggestions(max);
    }

    final suggestions = stageTemplates.take(max).toList();

    // Add fallback if needed
    while (suggestions.length < max) {
      suggestions.addAll(_getFallbackSuggestions(max - suggestions.length));
    }

    return suggestions.take(max).toList();
  }

  /// Get fallback suggestions
  List<String> _getFallbackSuggestions(int max) {
    final fallback = [
      'What specific aspect interests you?',
      'Would you like to explore this further?',
      'How can I help you with this?',
      'What would be most helpful to know?',
    ];
    fallback.shuffle();
    return fallback.take(max).toList();
  }
}

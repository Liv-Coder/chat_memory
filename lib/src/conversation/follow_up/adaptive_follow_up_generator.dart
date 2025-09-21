import '../../core/models/message.dart';
import '../../core/persistence/persistence_strategy.dart';
import '../../core/logging/chat_memory_logger.dart';
import 'follow_up_generator.dart';
import 'context_analyzer.dart';

/// User interaction data for learning patterns
class UserInteraction {
  final String suggestionId;
  final String suggestion;
  final ConversationContext context;
  final DateTime timestamp;
  final UserAction action;
  final double relevanceScore;

  const UserInteraction({
    required this.suggestionId,
    required this.suggestion,
    required this.context,
    required this.timestamp,
    required this.action,
    required this.relevanceScore,
  });

  Map<String, dynamic> toJson() => {
    'suggestionId': suggestionId,
    'suggestion': suggestion,
    'contextStage': context.stage.name,
    'contextType': context.lastMessageType.name,
    'timestamp': timestamp.toIso8601String(),
    'action': action.name,
    'relevanceScore': relevanceScore,
  };

  static UserInteraction fromJson(Map<String, dynamic> json) {
    return UserInteraction(
      suggestionId: json['suggestionId'],
      suggestion: json['suggestion'],
      context: ConversationContext(
        topics: [],
        topicScores: {},
        stage: ConversationStage.values.firstWhere(
          (e) => e.name == json['contextStage'],
        ),
        engagementLevel: 0.0,
        lastMessageType: MessageType.values.firstWhere(
          (e) => e.name == json['contextType'],
        ),
        keywords: [],
        metadata: {},
        momentum: 0.0,
      ),
      timestamp: DateTime.parse(json['timestamp']),
      action: UserAction.values.firstWhere((e) => e.name == json['action']),
      relevanceScore: json['relevanceScore']?.toDouble() ?? 0.0,
    );
  }
}

/// Types of user actions on suggestions
enum UserAction {
  selected, // User clicked/selected the suggestion
  ignored, // User saw but did not select
  modified, // User edited the suggestion before using
  dismissed, // User explicitly dismissed/removed
}

/// Learned user preferences and patterns
class UserPatterns {
  final Map<ConversationStage, List<String>> preferredSuggestions;
  final Map<MessageType, double> typePreferences;
  final Map<String, double> topicPreferences;
  final double avgInteractionTime;
  final int totalInteractions;

  const UserPatterns({
    required this.preferredSuggestions,
    required this.typePreferences,
    required this.topicPreferences,
    required this.avgInteractionTime,
    required this.totalInteractions,
  });

  UserPatterns copyWith({
    Map<ConversationStage, List<String>>? preferredSuggestions,
    Map<MessageType, double>? typePreferences,
    Map<String, double>? topicPreferences,
    double? avgInteractionTime,
    int? totalInteractions,
  }) {
    return UserPatterns(
      preferredSuggestions: preferredSuggestions ?? this.preferredSuggestions,
      typePreferences: typePreferences ?? this.typePreferences,
      topicPreferences: topicPreferences ?? this.topicPreferences,
      avgInteractionTime: avgInteractionTime ?? this.avgInteractionTime,
      totalInteractions: totalInteractions ?? this.totalInteractions,
    );
  }
}

/// Configuration for adaptive learning
class AdaptiveConfig {
  final int maxInteractionHistory;
  final double learningRate;
  final Duration interactionWindow;
  final double minimumConfidence;

  const AdaptiveConfig({
    this.maxInteractionHistory = 1000,
    this.learningRate = 0.1,
    this.interactionWindow = const Duration(days: 30),
    this.minimumConfidence = 0.3,
  });
}

/// Adaptive follow-up generator that learns from user interactions
class AdaptiveFollowUpGenerator implements FollowUpGenerator {
  static final _logger = ChatMemoryLogger.loggerFor(
    'adaptive_follow_up_generator',
  );

  final AdaptiveConfig config;
  final ContextAnalyzer _contextAnalyzer;
  final FollowUpGenerator _fallbackGenerator;
  final PersistenceStrategy? _persistence;

  final List<UserInteraction> _interactions = [];
  UserPatterns? _learnedPatterns;

  AdaptiveFollowUpGenerator({
    AdaptiveConfig? config,
    ContextAnalyzer? contextAnalyzer,
    FollowUpGenerator? fallbackGenerator,
    PersistenceStrategy? persistence,
  }) : config = config ?? const AdaptiveConfig(),
       _contextAnalyzer = contextAnalyzer ?? ContextAnalyzer(),
       _fallbackGenerator = fallbackGenerator ?? HeuristicFollowUpGenerator(),
       _persistence = persistence;

  @override
  Future<List<String>> generate(List<Message> messages, {int max = 3}) async {
    final sw = ChatMemoryLogger.logOperationStart(
      _logger,
      'generate',
      params: {'messageCount': messages.length, 'max': max},
    );

    try {
      if (messages.isEmpty) {
        return await _useFallback(messages, max);
      }

      // Analyze context
      final context = await _contextAnalyzer.analyzeContext(messages);

      // Load user patterns if not already loaded
      if (_learnedPatterns == null) {
        await _loadUserPatterns();
      }

      // Generate adaptive suggestions
      final suggestions = _generateAdaptiveSuggestions(context, max);

      // Fall back if insufficient adaptive suggestions
      if (suggestions.length < max) {
        final fallback = await _fallbackGenerator.generate(
          messages,
          max: max - suggestions.length,
        );
        suggestions.addAll(fallback);
      }

      ChatMemoryLogger.logOperationEnd(
        _logger,
        'generate',
        sw,
        result: {'suggestionCount': suggestions.length},
      );

      return suggestions.take(max).toList();
    } catch (error, stackTrace) {
      ChatMemoryLogger.logError(
        _logger,
        'generate',
        error,
        stackTrace: stackTrace,
        shouldRethrow: false,
      );
      return await _useFallback(messages, max);
    }
  }

  /// Record user interaction with a suggestion
  Future<void> recordInteraction({
    required String suggestionId,
    required String suggestion,
    required ConversationContext context,
    required UserAction action,
    double? relevanceScore,
  }) async {
    final interaction = UserInteraction(
      suggestionId: suggestionId,
      suggestion: suggestion,
      context: context,
      timestamp: DateTime.now(),
      action: action,
      relevanceScore: relevanceScore ?? _calculateDefaultScore(action),
    );

    _interactions.add(interaction);

    // Limit interaction history
    if (_interactions.length > config.maxInteractionHistory) {
      _interactions.removeAt(0);
    }

    // Update learned patterns
    await _updatePatterns();

    // Persist if available
    if (_persistence != null) {
      await _saveInteractionData();
    }

    _logger.fine('Recorded user interaction: ${action.name} for "$suggestion"');
  }

  /// Generate suggestions based on learned user patterns
  List<String> _generateAdaptiveSuggestions(
    ConversationContext context,
    int max,
  ) {
    if (_learnedPatterns == null || _learnedPatterns!.totalInteractions < 5) {
      return []; // Need more data to make adaptive suggestions
    }

    final suggestions = <String>[];
    final patterns = _learnedPatterns!;

    // Get stage-specific preferred suggestions
    final stagePreferences = patterns.preferredSuggestions[context.stage] ?? [];
    suggestions.addAll(stagePreferences.take(2));

    // Add suggestions based on topic preferences
    for (final topic in context.topics.take(2)) {
      final topicScore = patterns.topicPreferences[topic] ?? 0.0;
      if (topicScore > config.minimumConfidence) {
        suggestions.add('Would you like to explore more about $topic?');
      }
    }

    // Add type-based suggestions if confident
    final typeScore = patterns.typePreferences[context.lastMessageType] ?? 0.0;
    if (typeScore > config.minimumConfidence) {
      suggestions.addAll(_getTypeSuggestions(context.lastMessageType));
    }

    return _deduplicateAndScore(suggestions, context).take(max).toList();
  }

  /// Get suggestions based on message type
  List<String> _getTypeSuggestions(MessageType type) {
    switch (type) {
      case MessageType.question:
        return [
          'Would you like more details on this?',
          'Should I provide examples?',
        ];
      case MessageType.request:
        return [
          'How can I best help with this?',
          'What approach would you prefer?',
        ];
      case MessageType.clarification:
        return [
          'Does this help clarify things?',
          'Should I explain differently?',
        ];
      default:
        return ['How would you like to proceed?'];
    }
  }

  /// Update learned patterns based on recent interactions
  Future<void> _updatePatterns() async {
    if (_interactions.isEmpty) return;

    final recentInteractions = _getRecentInteractions();
    if (recentInteractions.isEmpty) return;

    final stagePrefs = <ConversationStage, List<String>>{};
    final typePrefs = <MessageType, double>{};
    final topicPrefs = <String, double>{};

    // Analyze successful interactions (selected or modified)
    final successfulInteractions = recentInteractions
        .where(
          (i) =>
              i.action == UserAction.selected ||
              i.action == UserAction.modified,
        )
        .toList();

    // Learn stage preferences
    for (final stage in ConversationStage.values) {
      final stageSuggestions = successfulInteractions
          .where((i) => i.context.stage == stage)
          .map((i) => i.suggestion)
          .take(3)
          .toList();
      if (stageSuggestions.isNotEmpty) {
        stagePrefs[stage] = stageSuggestions;
      }
    }

    // Learn type preferences
    for (final type in MessageType.values) {
      final typeInteractions = recentInteractions.where(
        (i) => i.context.lastMessageType == type,
      );
      if (typeInteractions.isNotEmpty) {
        final avgScore =
            typeInteractions
                .map((i) => i.relevanceScore)
                .reduce((a, b) => a + b) /
            typeInteractions.length;
        typePrefs[type] = avgScore;
      }
    }

    // Learn topic preferences
    final topicCounts = <String, int>{};
    final topicScores = <String, double>{};

    for (final interaction in successfulInteractions) {
      for (final topic in interaction.context.topics) {
        topicCounts[topic] = (topicCounts[topic] ?? 0) + 1;
        topicScores[topic] =
            (topicScores[topic] ?? 0.0) + interaction.relevanceScore;
      }
    }

    for (final topic in topicCounts.keys) {
      final count = topicCounts[topic]!;
      final avgScore = topicScores[topic]! / count;
      topicPrefs[topic] = avgScore;
    }

    // Calculate average interaction time (mock implementation)
    final avgTime = recentInteractions.isNotEmpty
        ? recentInteractions.map((i) => 5.0).reduce((a, b) => a + b) /
              recentInteractions.length
        : 0.0;

    _learnedPatterns = UserPatterns(
      preferredSuggestions: stagePrefs,
      typePreferences: typePrefs,
      topicPreferences: topicPrefs,
      avgInteractionTime: avgTime,
      totalInteractions: _interactions.length,
    );

    _logger.fine(
      'Updated user patterns with ${recentInteractions.length} recent interactions',
    );
  }

  /// Get recent interactions within the configured window
  List<UserInteraction> _getRecentInteractions() {
    final cutoff = DateTime.now().subtract(config.interactionWindow);
    return _interactions.where((i) => i.timestamp.isAfter(cutoff)).toList();
  }

  /// Calculate default relevance score based on action
  double _calculateDefaultScore(UserAction action) {
    switch (action) {
      case UserAction.selected:
        return 1.0;
      case UserAction.modified:
        return 0.8;
      case UserAction.ignored:
        return 0.2;
      case UserAction.dismissed:
        return 0.0;
    }
  }

  /// Deduplicate and score suggestions
  List<String> _deduplicateAndScore(
    List<String> suggestions,
    ConversationContext context,
  ) {
    final unique = <String>{};
    final deduped = <String>[];

    for (final suggestion in suggestions) {
      if (unique.add(suggestion)) {
        deduped.add(suggestion);
      }
    }

    // Could add scoring logic here based on context
    return deduped;
  }

  /// Load user patterns from persistence
  Future<void> _loadUserPatterns() async {
    // Mock implementation - would load from actual persistence
    _learnedPatterns = const UserPatterns(
      preferredSuggestions: {},
      typePreferences: {},
      topicPreferences: {},
      avgInteractionTime: 0.0,
      totalInteractions: 0,
    );

    _logger.fine('Loaded user patterns (mock implementation)');
  }

  /// Save interaction data to persistence
  Future<void> _saveInteractionData() async {
    // Mock implementation - would save to actual persistence
    _logger.fine('Saved interaction data (mock implementation)');
  }

  /// Use fallback generator
  Future<List<String>> _useFallback(List<Message> messages, int max) async {
    return await _fallbackGenerator.generate(messages, max: max);
  }
}

import '../../core/models/message.dart';
import '../../core/utils/token_counter.dart';
import '../../core/logging/chat_memory_logger.dart';

/// Context information extracted from conversation analysis
class ConversationContext {
  final List<String> topics;
  final Map<String, double> topicScores;
  final ConversationStage stage;
  final double engagementLevel;
  final MessageType lastMessageType;
  final String? dominantSentiment;
  final List<String> keywords;
  final Map<String, dynamic> metadata;
  final double momentum;

  const ConversationContext({
    required this.topics,
    required this.topicScores,
    required this.stage,
    required this.engagementLevel,
    required this.lastMessageType,
    this.dominantSentiment,
    required this.keywords,
    required this.metadata,
    required this.momentum,
  });

  ConversationContext copyWith({
    List<String>? topics,
    Map<String, double>? topicScores,
    ConversationStage? stage,
    double? engagementLevel,
    MessageType? lastMessageType,
    String? dominantSentiment,
    List<String>? keywords,
    Map<String, dynamic>? metadata,
    double? momentum,
  }) {
    return ConversationContext(
      topics: topics ?? this.topics,
      topicScores: topicScores ?? this.topicScores,
      stage: stage ?? this.stage,
      engagementLevel: engagementLevel ?? this.engagementLevel,
      lastMessageType: lastMessageType ?? this.lastMessageType,
      dominantSentiment: dominantSentiment ?? this.dominantSentiment,
      keywords: keywords ?? this.keywords,
      metadata: metadata ?? this.metadata,
      momentum: momentum ?? this.momentum,
    );
  }
}

/// Stages of conversation development
enum ConversationStage {
  opening, // Initial exchanges, introductions
  development, // Main discussion, exploration
  clarification, // Seeking clarity, asking questions
  closing, // Wrapping up, conclusions
  completed, // Finished discussion
}

/// Types of messages based on intent analysis
enum MessageType {
  question, // Direct questions
  statement, // Assertions, declarations
  request, // Action requests, commands
  clarification, // Seeking clarification
  followUp, // Building on previous messages
  completion, // Ending statements
  greeting, // Opening/closing greetings
  unknown, // Unable to classify
}

/// Analyzes conversation context to provide insights for follow-up generation
class ContextAnalyzer {
  static final _logger = ChatMemoryLogger.loggerFor('context_analyzer');
  final TokenCounter _tokenCounter;

  // Keyword sets for classification
  static const _questionWords = {
    'what',
    'how',
    'why',
    'when',
    'where',
    'who',
    'which',
    'can',
    'could',
    'would',
    'should',
    'is',
    'are',
    'do',
    'does',
    'did',
    'will',
    'was',
    'were',
  };

  static const _requestWords = {
    'please',
    'help',
    'show',
    'explain',
    'tell',
    'give',
    'provide',
    'create',
    'make',
    'build',
    'implement',
    'fix',
    'solve',
    'generate',
    'write',
  };

  static const _clarificationWords = {
    'clarify',
    'mean',
    'understand',
    'confused',
    'unclear',
    'explain',
    'elaborate',
    'detail',
    'specific',
    'example',
    'instance',
  };

  static const _completionWords = {
    'done',
    'finished',
    'complete',
    'thanks',
    'thank',
    'perfect',
    'great',
    'excellent',
    'good',
    'okay',
    'ok',
    'bye',
    'goodbye',
    'that\'s all',
  };

  static const _greetingWords = {
    'hello',
    'hi',
    'hey',
    'good morning',
    'good afternoon',
    'good evening',
    'bye',
    'goodbye',
    'see you',
    'farewell',
    'thanks',
    'thank you',
  };

  static const _positiveWords = {
    'good',
    'great',
    'excellent',
    'perfect',
    'awesome',
    'amazing',
    'wonderful',
    'fantastic',
    'brilliant',
    'outstanding',
    'superb',
    'love',
    'like',
    'happy',
    'pleased',
    'satisfied',
    'impressed',
    'helpful',
    'useful',
    'clear',
  };

  static const _negativeWords = {
    'bad',
    'terrible',
    'awful',
    'horrible',
    'poor',
    'disappointing',
    'wrong',
    'error',
    'problem',
    'issue',
    'confused',
    'unclear',
    'difficult',
    'hard',
    'frustrating',
    'annoying',
    'hate',
    'dislike',
    'unhappy',
    'dissatisfied',
  };

  ContextAnalyzer({TokenCounter? tokenCounter})
    : _tokenCounter = tokenCounter ?? HeuristicTokenCounter();

  /// Analyze conversation messages to extract context information
  Future<ConversationContext> analyzeContext(List<Message> messages) async {
    final sw = ChatMemoryLogger.logOperationStart(
      _logger,
      'analyzeContext',
      params: {'messageCount': messages.length},
    );

    try {
      // Filter to user and assistant messages only
      final conversationMessages = messages
          .where(
            (m) =>
                m.role == MessageRole.user || m.role == MessageRole.assistant,
          )
          .toList();

      if (conversationMessages.isEmpty) {
        return _emptyContext();
      }

      // Extract topics and keywords
      final topicAnalysis = _analyzeTopics(conversationMessages);
      final keywords = _extractKeywords(conversationMessages);

      // Analyze conversation stage
      final stage = _determineConversationStage(conversationMessages);

      // Classify last message type
      final lastMessageType = _classifyMessageType(conversationMessages.last);

      // Calculate engagement level
      final engagementLevel = _calculateEngagementLevel(conversationMessages);

      // Analyze sentiment
      final sentiment = _analyzeSentiment(conversationMessages);

      // Calculate conversation momentum
      final momentum = _calculateMomentum(conversationMessages);

      // Build metadata
      final metadata = {
        'messageCount': conversationMessages.length,
        'totalTokens': conversationMessages
            .map((m) => _tokenCounter.estimateTokens(m.content))
            .reduce((a, b) => a + b),
        'avgMessageLength': conversationMessages.isNotEmpty
            ? conversationMessages
                      .map((m) => m.content.length)
                      .reduce((a, b) => a + b) /
                  conversationMessages.length
            : 0.0,
        'timeSpan': conversationMessages.isNotEmpty
            ? conversationMessages.last.timestamp
                  .difference(conversationMessages.first.timestamp)
                  .inMinutes
            : 0,
      };

      final context = ConversationContext(
        topics: topicAnalysis.keys.toList(),
        topicScores: topicAnalysis,
        stage: stage,
        engagementLevel: engagementLevel,
        lastMessageType: lastMessageType,
        dominantSentiment: sentiment,
        keywords: keywords,
        metadata: metadata,
        momentum: momentum,
      );

      ChatMemoryLogger.logOperationEnd(
        _logger,
        'analyzeContext',
        sw,
        result: {
          'topicCount': context.topics.length,
          'stage': context.stage.name,
          'engagementLevel': context.engagementLevel,
          'momentum': context.momentum,
        },
      );

      return context;
    } catch (error, stackTrace) {
      ChatMemoryLogger.logError(
        _logger,
        'analyzeContext',
        error,
        stackTrace: stackTrace,
        shouldRethrow: false,
      );
      return _emptyContext();
    }
  }

  /// Extract topics using keyword frequency analysis
  Map<String, double> _analyzeTopics(List<Message> messages) {
    final wordFreq = <String, int>{};
    final stopWords = {
      'the',
      'a',
      'an',
      'and',
      'or',
      'but',
      'in',
      'on',
      'at',
      'to',
      'for',
      'of',
      'with',
      'by',
      'from',
      'up',
      'about',
      'into',
      'through',
      'during',
      'before',
      'after',
      'above',
      'below',
      'between',
      'among',
      'this',
      'that',
      'these',
      'those',
      'i',
      'you',
      'he',
      'she',
      'it',
      'we',
      'they',
      'me',
      'him',
      'her',
      'us',
      'them',
      'my',
      'your',
      'his',
      'its',
      'our',
      'their',
      'am',
      'is',
      'are',
      'was',
      'were',
      'be',
      'been',
      'being',
      'have',
      'has',
      'had',
      'do',
      'does',
      'did',
      'will',
      'would',
      'could',
      'should',
      'may',
      'might',
      'must',
      'shall',
      'can',
    };

    // Extract words from all messages
    for (final message in messages) {
      final words = message.content
          .toLowerCase()
          .replaceAll(RegExp(r'[^\w\s]'), ' ')
          .split(RegExp(r'\s+'))
          .where((word) => word.length > 2 && !stopWords.contains(word));

      for (final word in words) {
        wordFreq[word] = (wordFreq[word] ?? 0) + 1;
      }
    }

    // Convert to scores (frequency / total words)
    final totalWords = wordFreq.values.reduce((a, b) => a + b);
    final topicScores = <String, double>{};

    // Take top topics by frequency
    final sortedWords = wordFreq.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    for (final entry in sortedWords.take(10)) {
      topicScores[entry.key] = entry.value / totalWords;
    }

    return topicScores;
  }

  /// Extract significant keywords from conversation
  List<String> _extractKeywords(List<Message> messages) {
    final allWords = <String>[];

    for (final message in messages) {
      final words = message.content
          .toLowerCase()
          .replaceAll(RegExp(r'[^\w\s]'), ' ')
          .split(RegExp(r'\s+'))
          .where((word) => word.length > 3);
      allWords.addAll(words);
    }

    // Get unique words sorted by frequency
    final wordCount = <String, int>{};
    for (final word in allWords) {
      wordCount[word] = (wordCount[word] ?? 0) + 1;
    }

    final keywords = wordCount.entries
        .where((e) => e.value > 1) // Appeared more than once
        .map((e) => e.key)
        .take(15)
        .toList();

    return keywords;
  }

  /// Determine the current stage of conversation
  ConversationStage _determineConversationStage(List<Message> messages) {
    if (messages.length <= 2) {
      return ConversationStage.opening;
    }

    final recentMessages = messages.length > 5
        ? messages.sublist(messages.length - 5)
        : messages;

    final completionCount = recentMessages
        .where((m) => _containsWords(m.content, _completionWords))
        .length;

    final clarificationCount = recentMessages
        .where((m) => _containsWords(m.content, _clarificationWords))
        .length;

    if (completionCount >= 2) {
      return ConversationStage.closing;
    }

    if (clarificationCount >= 2) {
      return ConversationStage.clarification;
    }

    if (messages.length > 10) {
      return ConversationStage.development;
    }

    return ConversationStage.opening;
  }

  /// Classify the type of the given message
  MessageType _classifyMessageType(Message message) {
    final content = message.content.toLowerCase();

    if (_containsWords(content, _greetingWords)) {
      return MessageType.greeting;
    }

    if (_containsWords(content, _completionWords)) {
      return MessageType.completion;
    }

    if (_containsWords(content, _clarificationWords)) {
      return MessageType.clarification;
    }

    if (_containsWords(content, _requestWords)) {
      return MessageType.request;
    }

    if (_containsWords(content, _questionWords) || content.contains('?')) {
      return MessageType.question;
    }

    // Check for follow-up patterns
    if (content.startsWith('also') ||
        content.startsWith('additionally') ||
        content.contains('furthermore') ||
        content.contains('moreover')) {
      return MessageType.followUp;
    }

    // Default to statement
    return MessageType.statement;
  }

  /// Calculate engagement level based on message patterns
  double _calculateEngagementLevel(List<Message> messages) {
    if (messages.isEmpty) return 0.0;

    double score = 0.0;
    final recentMessages = messages.length > 5
        ? messages.sublist(messages.length - 5)
        : messages;

    // Question engagement
    final questionCount = recentMessages
        .where((m) => _classifyMessageType(m) == MessageType.question)
        .length;
    score += questionCount * 0.2;

    // Length engagement (longer messages = more engagement)
    final avgLength =
        recentMessages.map((m) => m.content.length).reduce((a, b) => a + b) /
        recentMessages.length;
    score += (avgLength / 100).clamp(0.0, 0.3);

    // Frequency engagement (more recent messages = higher engagement)
    if (recentMessages.length >= 2) {
      final timeSpan = recentMessages.last.timestamp
          .difference(recentMessages.first.timestamp)
          .inMinutes;
      if (timeSpan > 0) {
        final frequency = recentMessages.length / timeSpan;
        score += (frequency * 10).clamp(0.0, 0.3);
      }
    }

    // Positive sentiment boosts engagement
    final sentiment = _analyzeSentiment(recentMessages);
    if (sentiment == 'positive') {
      score += 0.2;
    }

    return score.clamp(0.0, 1.0);
  }

  /// Analyze sentiment of recent messages
  String? _analyzeSentiment(List<Message> messages) {
    if (messages.isEmpty) return null;

    final recentMessages = messages.length > 3
        ? messages.sublist(messages.length - 3)
        : messages;

    int positiveCount = 0;
    int negativeCount = 0;

    for (final message in recentMessages) {
      final content = message.content.toLowerCase();

      if (_containsWords(content, _positiveWords)) {
        positiveCount++;
      }

      if (_containsWords(content, _negativeWords)) {
        negativeCount++;
      }
    }

    if (positiveCount > negativeCount) {
      return 'positive';
    } else if (negativeCount > positiveCount) {
      return 'negative';
    } else {
      return 'neutral';
    }
  }

  /// Calculate conversation momentum (how active/dynamic the conversation is)
  double _calculateMomentum(List<Message> messages) {
    if (messages.length < 2) return 0.0;

    final recentMessages = messages.length > 6
        ? messages.sublist(messages.length - 6)
        : messages;

    // Time-based momentum
    final timeSpan = recentMessages.last.timestamp
        .difference(recentMessages.first.timestamp)
        .inMinutes;

    double momentum = 0.0;

    if (timeSpan > 0) {
      final frequency = recentMessages.length / timeSpan;
      momentum += (frequency * 20).clamp(0.0, 0.4);
    }

    // Content-based momentum (questions and requests increase momentum)
    final activeTypes = recentMessages.where((m) {
      final type = _classifyMessageType(m);
      return type == MessageType.question ||
          type == MessageType.request ||
          type == MessageType.clarification;
    }).length;

    momentum += (activeTypes / recentMessages.length) * 0.4;

    // Length variation (varied message lengths = more dynamic)
    if (recentMessages.length > 1) {
      final lengths = recentMessages.map((m) => m.content.length).toList();
      final avgLength = lengths.reduce((a, b) => a + b) / lengths.length;
      final variance =
          lengths
              .map((len) => (len - avgLength) * (len - avgLength))
              .reduce((a, b) => a + b) /
          lengths.length;
      momentum += (variance / 10000).clamp(0.0, 0.2);
    }

    return momentum.clamp(0.0, 1.0);
  }

  /// Check if content contains any of the specified words
  bool _containsWords(String content, Set<String> words) {
    final contentWords = content.toLowerCase().split(RegExp(r'\s+'));
    return words.any(
      (word) =>
          contentWords.contains(word) ||
          contentWords.any((cw) => cw.contains(word)),
    );
  }

  /// Return empty context for error cases
  ConversationContext _emptyContext() {
    return const ConversationContext(
      topics: [],
      topicScores: {},
      stage: ConversationStage.opening,
      engagementLevel: 0.0,
      lastMessageType: MessageType.unknown,
      dominantSentiment: null,
      keywords: [],
      metadata: {},
      momentum: 0.0,
    );
  }
}

import '../../core/errors.dart';
import '../../core/logging/chat_memory_logger.dart';
import '../../core/models/message.dart';
import '../../core/utils/token_counter.dart';
import '../../memory/memory_manager.dart';

/// Statistics about a conversation
class ConversationStats {
  final int totalMessages;
  final int userMessages;
  final int assistantMessages;
  final int systemMessages;
  final int summaryMessages;
  final int totalTokens;
  final int? vectorCount;
  final DateTime? oldestMessage;
  final DateTime? newestMessage;

  const ConversationStats({
    required this.totalMessages,
    required this.userMessages,
    required this.assistantMessages,
    required this.systemMessages,
    required this.summaryMessages,
    required this.totalTokens,
    this.vectorCount,
    this.oldestMessage,
    this.newestMessage,
  });

  /// Calculate conversation duration
  Duration? get conversationDuration {
    if (oldestMessage == null || newestMessage == null) return null;
    return newestMessage!.difference(oldestMessage!);
  }

  /// Convert to JSON representation
  Map<String, dynamic> toJson() {
    return {
      'totalMessages': totalMessages,
      'userMessages': userMessages,
      'assistantMessages': assistantMessages,
      'systemMessages': systemMessages,
      'summaryMessages': summaryMessages,
      'totalTokens': totalTokens,
      'vectorCount': vectorCount,
      'oldestMessage': oldestMessage?.toIso8601String(),
      'newestMessage': newestMessage?.toIso8601String(),
      'conversationDurationMinutes': conversationDuration?.inMinutes,
    };
  }

  /// Create from JSON representation
  factory ConversationStats.fromJson(Map<String, dynamic> json) {
    return ConversationStats(
      totalMessages: json['totalMessages'] as int,
      userMessages: json['userMessages'] as int,
      assistantMessages: json['assistantMessages'] as int,
      systemMessages: json['systemMessages'] as int,
      summaryMessages: json['summaryMessages'] as int,
      totalTokens: json['totalTokens'] as int,
      vectorCount: json['vectorCount'] as int?,
      oldestMessage: json['oldestMessage'] != null
          ? DateTime.parse(json['oldestMessage'] as String)
          : null,
      newestMessage: json['newestMessage'] != null
          ? DateTime.parse(json['newestMessage'] as String)
          : null,
    );
  }

  @override
  String toString() {
    return 'ConversationStats('
        'total: $totalMessages, '
        'user: $userMessages, '
        'assistant: $assistantMessages, '
        'system: $systemMessages, '
        'summary: $summaryMessages, '
        'tokens: $totalTokens, '
        'vectors: ${vectorCount ?? 'N/A'}'
        ')';
  }
}

/// Advanced conversation metrics and patterns
class ConversationMetrics {
  final double averageMessageLength;
  final double messageFrequency; // messages per minute
  final Duration conversationDuration;
  final Map<MessageRole, double> tokenDistribution;
  final Map<MessageRole, double> messageDistribution;
  final int longestMessage;
  final int shortestMessage;

  const ConversationMetrics({
    required this.averageMessageLength,
    required this.messageFrequency,
    required this.conversationDuration,
    required this.tokenDistribution,
    required this.messageDistribution,
    required this.longestMessage,
    required this.shortestMessage,
  });

  Map<String, dynamic> toJson() {
    return {
      'averageMessageLength': averageMessageLength,
      'messageFrequency': messageFrequency,
      'conversationDuration': conversationDuration.inSeconds,
      'tokenDistribution': tokenDistribution.map(
        (k, v) => MapEntry(k.toString(), v),
      ),
      'messageDistribution': messageDistribution.map(
        (k, v) => MapEntry(k.toString(), v),
      ),
      'longestMessage': longestMessage,
      'shortestMessage': shortestMessage,
    };
  }
}

/// Handles conversation statistics and analytics calculations
///
/// This class provides comprehensive metrics calculation including message counts,
/// token analysis, conversation patterns, and vector store integration with
/// proper error handling and caching mechanisms.
class ConversationAnalytics {
  final TokenCounter _tokenCounter;
  final _logger = ChatMemoryLogger.loggerFor('analytics.conversation');

  // Caching for expensive operations
  final Map<String, int> _tokenCache = <String, int>{};
  final Map<String, ConversationStats> _statsCache =
      <String, ConversationStats>{};

  ConversationAnalytics({required TokenCounter tokenCounter})
    : _tokenCounter = tokenCounter;

  /// Calculate comprehensive conversation statistics
  Future<ConversationStats> calculateStats({
    required List<Message> messages,
    MemoryManager? memoryManager,
  }) async {
    final opCtx = ErrorContext(
      component: 'ConversationAnalytics',
      operation: 'calculateStats',
      params: {'messageCount': messages.length},
    );

    try {
      _logger.fine('Calculating conversation statistics', opCtx.toMap());

      // Calculate message counts by role
      final userMessages = messages.where((m) => m.role == MessageRole.user);
      final assistantMessages = messages.where(
        (m) => m.role == MessageRole.assistant,
      );
      final systemMessages = messages.where(
        (m) => m.role == MessageRole.system,
      );
      final summaryMessages = messages.where(
        (m) => m.role == MessageRole.summary,
      );

      // Calculate total tokens with caching
      final totalTokens = _calculateTotalTokensWithCache(messages);

      // Get vector store stats if available
      int? vectorCount;
      if (memoryManager?.vectorStore != null) {
        try {
          vectorCount = await memoryManager!.vectorStore!.count();
        } catch (e) {
          _logger.warning('Failed to get vector count', {
            ...opCtx.toMap(),
            'error': e.toString(),
          });
          // Continue without vector count
        }
      }

      // Calculate timestamps
      DateTime? oldestMessage;
      DateTime? newestMessage;
      if (messages.isNotEmpty) {
        final sortedMessages = List<Message>.from(messages)
          ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
        oldestMessage = sortedMessages.first.timestamp;
        newestMessage = sortedMessages.last.timestamp;
      }

      final stats = ConversationStats(
        totalMessages: messages.length,
        userMessages: userMessages.length,
        assistantMessages: assistantMessages.length,
        systemMessages: systemMessages.length,
        summaryMessages: summaryMessages.length,
        totalTokens: totalTokens,
        vectorCount: vectorCount,
        oldestMessage: oldestMessage,
        newestMessage: newestMessage,
      );

      _logger.fine('Statistics calculation completed', {
        ...opCtx.toMap(),
        'stats': stats.toString(),
      });

      return stats;
    } catch (e, st) {
      ChatMemoryLogger.logError(
        _logger,
        'calculateStats',
        e,
        stackTrace: st,
        params: opCtx.toMap(),
        shouldRethrow: false,
      );

      // Return basic stats on error
      return ConversationStats(
        totalMessages: messages.length,
        userMessages: messages.where((m) => m.role == MessageRole.user).length,
        assistantMessages: messages
            .where((m) => m.role == MessageRole.assistant)
            .length,
        systemMessages: messages
            .where((m) => m.role == MessageRole.system)
            .length,
        summaryMessages: messages
            .where((m) => m.role == MessageRole.summary)
            .length,
        totalTokens: 0,
        vectorCount: null,
        oldestMessage: null,
        newestMessage: null,
      );
    }
  }

  /// Calculate advanced conversation metrics and patterns
  Future<ConversationMetrics> calculateMetrics(List<Message> messages) async {
    final opCtx = ErrorContext(
      component: 'ConversationAnalytics',
      operation: 'calculateMetrics',
      params: {'messageCount': messages.length},
    );

    try {
      if (messages.isEmpty) {
        return const ConversationMetrics(
          averageMessageLength: 0.0,
          messageFrequency: 0.0,
          conversationDuration: Duration.zero,
          tokenDistribution: {},
          messageDistribution: {},
          longestMessage: 0,
          shortestMessage: 0,
        );
      }

      // Calculate message lengths
      final messageLengths = messages.map((m) => m.content.length).toList();
      final averageLength =
          messageLengths.fold<int>(0, (a, b) => a + b) / messages.length;
      final longestMessage = messageLengths.reduce((a, b) => a > b ? a : b);
      final shortestMessage = messageLengths.reduce((a, b) => a < b ? a : b);

      // Calculate conversation duration and frequency
      final sortedMessages = List<Message>.from(messages)
        ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
      final duration = sortedMessages.last.timestamp.difference(
        sortedMessages.first.timestamp,
      );
      final frequency = duration.inMinutes > 0
          ? messages.length / duration.inMinutes
          : 0.0;

      // Calculate token and message distributions
      final tokenDistribution = await _calculateTokenDistribution(messages);
      final messageDistribution = _calculateMessageDistribution(messages);

      return ConversationMetrics(
        averageMessageLength: averageLength,
        messageFrequency: frequency,
        conversationDuration: duration,
        tokenDistribution: tokenDistribution,
        messageDistribution: messageDistribution,
        longestMessage: longestMessage,
        shortestMessage: shortestMessage,
      );
    } catch (e, st) {
      ChatMemoryLogger.logError(
        _logger,
        'calculateMetrics',
        e,
        stackTrace: st,
        params: opCtx.toMap(),
        shouldRethrow: false,
      );

      // Return empty metrics on error
      return const ConversationMetrics(
        averageMessageLength: 0.0,
        messageFrequency: 0.0,
        conversationDuration: Duration.zero,
        tokenDistribution: {},
        messageDistribution: {},
        longestMessage: 0,
        shortestMessage: 0,
      );
    }
  }

  /// Calculate total tokens with caching to avoid repeated expensive operations
  int _calculateTotalTokensWithCache(List<Message> messages) {
    final cacheKey = messages
        .map((m) => '${m.id}:${m.content.length}')
        .join('|');

    if (_tokenCache.containsKey(cacheKey)) {
      return _tokenCache[cacheKey]!;
    }

    final totalTokens = _tokenCounter.estimateTokens(
      messages.map((m) => m.content).join('\n'),
    );

    _tokenCache[cacheKey] = totalTokens;
    return totalTokens;
  }

  /// Calculate token distribution across message roles
  Future<Map<MessageRole, double>> _calculateTokenDistribution(
    List<Message> messages,
  ) async {
    final distribution = <MessageRole, int>{};
    int totalTokens = 0;

    for (final message in messages) {
      final tokens = _tokenCounter.estimateTokens(message.content);
      distribution[message.role] = (distribution[message.role] ?? 0) + tokens;
      totalTokens += tokens;
    }

    if (totalTokens == 0) return {};

    return distribution.map(
      (role, tokens) => MapEntry(role, tokens / totalTokens),
    );
  }

  /// Calculate message distribution across roles
  Map<MessageRole, double> _calculateMessageDistribution(
    List<Message> messages,
  ) {
    if (messages.isEmpty) return {};

    final distribution = <MessageRole, int>{};
    for (final message in messages) {
      distribution[message.role] = (distribution[message.role] ?? 0) + 1;
    }

    return distribution.map(
      (role, count) => MapEntry(role, count / messages.length),
    );
  }

  /// Export analytics data in JSON format
  Future<Map<String, dynamic>> exportAnalytics({
    required List<Message> messages,
    MemoryManager? memoryManager,
  }) async {
    final stats = await calculateStats(
      messages: messages,
      memoryManager: memoryManager,
    );
    final metrics = await calculateMetrics(messages);

    return {
      'timestamp': DateTime.now().toUtc().toIso8601String(),
      'stats': stats.toJson(),
      'metrics': metrics.toJson(),
      'cacheStats': {
        'tokenCacheSize': _tokenCache.length,
        'statsCacheSize': _statsCache.length,
      },
    };
  }

  /// Clear analytics caches
  void clearCache() {
    _tokenCache.clear();
    _statsCache.clear();
    _logger.fine('Analytics caches cleared');
  }

  /// Get cache statistics
  Map<String, int> getCacheStats() {
    return {
      'tokenCacheSize': _tokenCache.length,
      'statsCacheSize': _statsCache.length,
    };
  }
}

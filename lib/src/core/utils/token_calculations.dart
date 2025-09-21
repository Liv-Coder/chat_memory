import '../errors.dart';
import '../logging/chat_memory_logger.dart';
import '../models/message.dart';
import '../utils/token_counter.dart';

/// Enhanced token counting utilities for messages and conversations
///
/// This class extends the basic TokenCounter interface with message-specific
/// and conversation-level calculations, providing comprehensive token-related
/// operations for the chat memory system.
class TokenCalculations {
  final TokenCounter _tokenCounter;
  final _logger = ChatMemoryLogger.loggerFor('utils.token_calculations');

  // Cache for expensive token calculations
  final Map<String, int> _tokenCache = <String, int>{};

  // Configuration
  final bool _enableCaching;
  final int _maxCacheSize;

  TokenCalculations({
    required TokenCounter tokenCounter,
    bool enableCaching = true,
    int maxCacheSize = 1000,
  }) : _tokenCounter = tokenCounter,
       _enableCaching = enableCaching,
       _maxCacheSize = maxCacheSize;

  /// Estimate tokens for a single message with role-specific adjustments
  int estimateMessageTokens(Message message) {
    final opCtx = ErrorContext(
      component: 'TokenCalculations',
      operation: 'estimateMessageTokens',
      params: {
        'messageId': message.id,
        'role': message.role.toString(),
        'contentLength': message.content.length,
      },
    );

    try {
      final cacheKey = _generateCacheKey(message);

      // Check cache first if enabled
      if (_enableCaching && _tokenCache.containsKey(cacheKey)) {
        return _tokenCache[cacheKey]!;
      }

      // Base token count
      var tokens = _tokenCounter.estimateTokens(message.content);

      // Role-specific adjustments
      tokens += _getRoleTokenOverhead(message.role);

      // Metadata overhead if present
      if (message.metadata != null && message.metadata!.isNotEmpty) {
        tokens += _getMetadataTokenOverhead(message.metadata!);
      }

      // Cache the result if enabled
      if (_enableCaching) {
        _cacheTokenCount(cacheKey, tokens);
      }

      _logger.fine('Message token estimation completed', {
        ...opCtx.toMap(),
        'estimatedTokens': tokens,
        'cached': _enableCaching,
      });

      return tokens;
    } catch (e, st) {
      ChatMemoryLogger.logError(
        _logger,
        'estimateMessageTokens',
        e,
        stackTrace: st,
        params: opCtx.toMap(),
        shouldRethrow: false,
      );

      // Fallback to basic estimation
      return _tokenCounter.estimateTokens(message.content);
    }
  }

  /// Estimate tokens for multiple messages with batch optimization
  List<int> estimateMessageBatchTokens(List<Message> messages) {
    final opCtx = ErrorContext(
      component: 'TokenCalculations',
      operation: 'estimateMessageBatchTokens',
      params: {'messageCount': messages.length},
    );

    try {
      final tokenCounts = <int>[];

      for (final message in messages) {
        final tokens = estimateMessageTokens(message);
        tokenCounts.add(tokens);
      }

      _logger.fine('Batch token estimation completed', {
        ...opCtx.toMap(),
        'totalTokens': tokenCounts.fold<int>(0, (a, b) => a + b),
      });

      return tokenCounts;
    } catch (e, st) {
      ChatMemoryLogger.logError(
        _logger,
        'estimateMessageBatchTokens',
        e,
        stackTrace: st,
        params: opCtx.toMap(),
        shouldRethrow: false,
      );

      // Fallback to individual estimation
      return messages
          .map((m) => _tokenCounter.estimateTokens(m.content))
          .toList();
    }
  }

  /// Calculate total tokens for a conversation
  int calculateConversationTokens(
    List<Message> messages, {
    bool includeOverhead = true,
  }) {
    if (messages.isEmpty) return 0;

    final opCtx = ErrorContext(
      component: 'TokenCalculations',
      operation: 'calculateConversationTokens',
      params: {
        'messageCount': messages.length,
        'includeOverhead': includeOverhead,
      },
    );

    try {
      var totalTokens = 0;

      if (includeOverhead) {
        // Use detailed per-message calculation
        for (final message in messages) {
          totalTokens += estimateMessageTokens(message);
        }
      } else {
        // Use basic text-only calculation
        final combinedContent = messages.map((m) => m.content).join('\n');
        totalTokens = _tokenCounter.estimateTokens(combinedContent);
      }

      // Add conversation-level overhead (delimiters, formatting, etc.)
      if (includeOverhead && messages.length > 1) {
        totalTokens += _getConversationOverhead(messages.length);
      }

      _logger.fine('Conversation token calculation completed', {
        ...opCtx.toMap(),
        'totalTokens': totalTokens,
      });

      return totalTokens;
    } catch (e, st) {
      ChatMemoryLogger.logError(
        _logger,
        'calculateConversationTokens',
        e,
        stackTrace: st,
        params: opCtx.toMap(),
        shouldRethrow: false,
      );

      // Fallback calculation
      final combinedContent = messages.map((m) => m.content).join('\n');
      return _tokenCounter.estimateTokens(combinedContent);
    }
  }

  /// Analyze token distribution across different message types
  Map<MessageRole, TokenDistribution> analyzeTokenDistribution(
    List<Message> messages,
  ) {
    final opCtx = ErrorContext(
      component: 'TokenCalculations',
      operation: 'analyzeTokenDistribution',
      params: {'messageCount': messages.length},
    );

    try {
      final distribution = <MessageRole, TokenDistribution>{};
      final roleTokens = <MessageRole, List<int>>{};

      // Group tokens by role
      for (final message in messages) {
        final tokens = estimateMessageTokens(message);
        roleTokens.putIfAbsent(message.role, () => <int>[]).add(tokens);
      }

      // Calculate distribution statistics for each role
      for (final entry in roleTokens.entries) {
        final role = entry.key;
        final tokens = entry.value;

        tokens.sort();
        final total = tokens.fold<int>(0, (a, b) => a + b);
        final average = total / tokens.length;
        final median = tokens.length.isOdd
            ? tokens[tokens.length ~/ 2].toDouble()
            : (tokens[tokens.length ~/ 2 - 1] + tokens[tokens.length ~/ 2]) /
                  2.0;

        distribution[role] = TokenDistribution(
          totalTokens: total,
          messageCount: tokens.length,
          averageTokens: average,
          medianTokens: median,
          minTokens: tokens.first,
          maxTokens: tokens.last,
          percentage: messages.isNotEmpty
              ? (tokens.length / messages.length) * 100
              : 0.0,
        );
      }

      _logger.fine('Token distribution analysis completed', {
        ...opCtx.toMap(),
        'rolesAnalyzed': distribution.length,
      });

      return distribution;
    } catch (e, st) {
      ChatMemoryLogger.logError(
        _logger,
        'analyzeTokenDistribution',
        e,
        stackTrace: st,
        params: opCtx.toMap(),
        shouldRethrow: false,
      );
      return {};
    }
  }

  /// Validate that messages fit within a token budget
  ValidationResult validateTokenBudget({
    required List<Message> messages,
    required int tokenBudget,
    double reservePercentage = 0.1,
  }) {
    final opCtx = ErrorContext(
      component: 'TokenCalculations',
      operation: 'validateTokenBudget',
      params: {
        'messageCount': messages.length,
        'tokenBudget': tokenBudget,
        'reservePercentage': reservePercentage,
      },
    );

    try {
      final totalTokens = calculateConversationTokens(messages);
      final effectiveBudget = (tokenBudget * (1.0 - reservePercentage)).round();
      final isValid = totalTokens <= effectiveBudget;

      final result = ValidationResult(
        isValid: isValid,
        totalTokens: totalTokens,
        tokenBudget: tokenBudget,
        effectiveBudget: effectiveBudget,
        overflow: isValid ? 0 : totalTokens - effectiveBudget,
        utilization: tokenBudget > 0 ? (totalTokens / tokenBudget) * 100 : 0.0,
      );

      _logger.fine('Token budget validation completed', {
        ...opCtx.toMap(),
        'isValid': isValid,
        'utilization': result.utilization,
      });

      return result;
    } catch (e, st) {
      ChatMemoryLogger.logError(
        _logger,
        'validateTokenBudget',
        e,
        stackTrace: st,
        params: opCtx.toMap(),
        shouldRethrow: false,
      );

      return ValidationResult(
        isValid: false,
        totalTokens: 0,
        tokenBudget: tokenBudget,
        effectiveBudget: tokenBudget,
        overflow: 0,
        utilization: 0.0,
      );
    }
  }

  /// Generate cache key for message token calculation
  String _generateCacheKey(Message message) {
    return '${message.id}:${message.content.length}:${message.role.toString()}';
  }

  /// Cache token count with size management
  void _cacheTokenCount(String key, int tokens) {
    if (_tokenCache.length >= _maxCacheSize) {
      // Remove oldest entries (simple FIFO)
      final keysToRemove = _tokenCache.keys.take(_maxCacheSize ~/ 4).toList();
      for (final keyToRemove in keysToRemove) {
        _tokenCache.remove(keyToRemove);
      }
    }
    _tokenCache[key] = tokens;
  }

  /// Get role-specific token overhead
  int _getRoleTokenOverhead(MessageRole role) {
    switch (role) {
      case MessageRole.system:
        return 5; // System messages have formatting overhead
      case MessageRole.assistant:
        return 3; // Assistant messages have response formatting
      case MessageRole.summary:
        return 4; // Summary messages have special formatting
      case MessageRole.user:
        return 2; // Basic user message formatting
    }
  }

  /// Get metadata token overhead
  int _getMetadataTokenOverhead(Map<String, dynamic> metadata) {
    // Rough estimation: 1 token per metadata key-value pair
    return metadata.length;
  }

  /// Get conversation-level token overhead
  int _getConversationOverhead(int messageCount) {
    // Overhead for message delimiters, role indicators, etc.
    return messageCount * 2;
  }

  /// Clear token calculation cache
  void clearCache() {
    _tokenCache.clear();
    _logger.fine('Token calculation cache cleared');
  }

  /// Get cache statistics
  Map<String, dynamic> getCacheStats() {
    return {
      'size': _tokenCache.length,
      'maxSize': _maxCacheSize,
      'enabled': _enableCaching,
      'hitRate': 0.0, // Could be tracked with additional counters
    };
  }

  /// Get the underlying token counter
  TokenCounter get tokenCounter => _tokenCounter;
}

/// Token distribution statistics for a message role
class TokenDistribution {
  final int totalTokens;
  final int messageCount;
  final double averageTokens;
  final double medianTokens;
  final int minTokens;
  final int maxTokens;
  final double percentage;

  const TokenDistribution({
    required this.totalTokens,
    required this.messageCount,
    required this.averageTokens,
    required this.medianTokens,
    required this.minTokens,
    required this.maxTokens,
    required this.percentage,
  });

  Map<String, dynamic> toJson() {
    return {
      'totalTokens': totalTokens,
      'messageCount': messageCount,
      'averageTokens': averageTokens,
      'medianTokens': medianTokens,
      'minTokens': minTokens,
      'maxTokens': maxTokens,
      'percentage': percentage,
    };
  }

  @override
  String toString() {
    return 'TokenDistribution('
        'total: $totalTokens, '
        'count: $messageCount, '
        'avg: ${averageTokens.toStringAsFixed(1)}, '
        'range: $minTokens-$maxTokens'
        ')';
  }
}

/// Token budget validation result
class ValidationResult {
  final bool isValid;
  final int totalTokens;
  final int tokenBudget;
  final int effectiveBudget;
  final int overflow;
  final double utilization;

  const ValidationResult({
    required this.isValid,
    required this.totalTokens,
    required this.tokenBudget,
    required this.effectiveBudget,
    required this.overflow,
    required this.utilization,
  });

  Map<String, dynamic> toJson() {
    return {
      'isValid': isValid,
      'totalTokens': totalTokens,
      'tokenBudget': tokenBudget,
      'effectiveBudget': effectiveBudget,
      'overflow': overflow,
      'utilization': utilization,
    };
  }

  @override
  String toString() {
    return 'ValidationResult('
        'valid: $isValid, '
        'tokens: $totalTokens/$tokenBudget, '
        'utilization: ${utilization.toStringAsFixed(1)}%'
        ')';
  }
}

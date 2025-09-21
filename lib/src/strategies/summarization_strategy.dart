import 'dart:async';

import '../models/message.dart';
import '../utils/token_counter.dart';
import '../summarizers/summarizer.dart';
import 'context_strategy.dart';

import '../errors.dart';
import '../logging/chat_memory_logger.dart';

/// Configuration for the summarization strategy
class SummarizationStrategyConfig {
  /// Maximum tokens allowed in the final context
  final int maxTokens;

  /// Minimum number of recent messages to always keep
  final int minRecentMessages;

  /// Maximum number of messages to summarize in one chunk
  final int maxSummaryChunkSize;

  /// Whether to preserve system messages
  final bool preserveSystemMessages;

  /// Whether to preserve existing summary messages
  final bool preserveSummaryMessages;

  const SummarizationStrategyConfig({
    required this.maxTokens,
    this.minRecentMessages = 5,
    this.maxSummaryChunkSize = 20,
    this.preserveSystemMessages = true,
    this.preserveSummaryMessages = true,
  });
}

/// Enhanced context strategy that implements the hybrid memory flow
///
/// This strategy manages token budgets by:
/// 1. Always preserving recent messages within token budget
/// 2. Summarizing older messages when budget is exceeded
/// 3. Maintaining system and existing summary messages
/// 4. Supporting chunked summarization for better context preservation
class SummarizationStrategy implements ContextStrategy {
  final SummarizationStrategyConfig config;
  final Summarizer summarizer;
  final TokenCounter tokenCounter;

  // Logger for this component
  final _logger = ChatMemoryLogger.loggerFor('strategies.summarization');

  // Simple circuit-breaker state to avoid repeated summarizer failures
  int _failureCount = 0;
  bool _circuitOpen = false;
  DateTime? _circuitOpenedAt;
  final int _failureThreshold;
  final Duration _circuitCooldown;

  SummarizationStrategy({
    required this.config,
    required this.summarizer,
    required this.tokenCounter,
    int failureThreshold = 3,
    Duration circuitCooldown = const Duration(minutes: 1),
  }) : _failureThreshold = failureThreshold,
       _circuitCooldown = circuitCooldown {
    // Validate configuration parameters using shared Validation utilities
    final ctorCtx = ErrorContext(
      component: 'SummarizationStrategy',
      operation: 'constructor',
      params: {
        'maxTokens': config.maxTokens,
        'minRecentMessages': config.minRecentMessages,
        'maxSummaryChunkSize': config.maxSummaryChunkSize,
      },
    );

    Validation.validatePositive(
      'maxTokens',
      config.maxTokens,
      context: ctorCtx,
    );

    Validation.validateNonNegative(
      'minRecentMessages',
      config.minRecentMessages,
      context: ctorCtx,
    );

    Validation.validatePositive(
      'maxSummaryChunkSize',
      config.maxSummaryChunkSize,
      context: ctorCtx,
    );
  }

  @override
  Future<StrategyResult> apply({
    required List<Message> messages,
    required int tokenBudget,
    required TokenCounter tokenCounter,
  }) async {
    final opId = 'summarize_apply_${DateTime.now().microsecondsSinceEpoch}';
    final sw = Stopwatch()..start();
    _logger.fine('[$opId] apply() start - messages=${messages.length}');

    if (messages.isEmpty) {
      _logger.fine('[$opId] no messages to process, returning early.');
      return StrategyResult(
        included: [],
        excluded: [],
        summaries: [],
        name: 'SummarizationStrategy',
      );
    }

    // Use provided tokenBudget or fall back to config
    final effectiveBudget = tokenBudget > 0 ? tokenBudget : config.maxTokens;

    // Separate messages by type
    final systemMessages = messages
        .where((m) => m.role == MessageRole.system)
        .toList();
    final summaryMessages = messages
        .where((m) => m.role == MessageRole.summary)
        .toList();
    final conversationMessages = messages
        .where(
          (m) => m.role != MessageRole.system && m.role != MessageRole.summary,
        )
        .toList();

    // Calculate tokens for system and summary messages
    int reservedTokens = 0;
    final preservedMessages = <Message>[];

    if (config.preserveSystemMessages) {
      preservedMessages.addAll(systemMessages);
      reservedTokens += _calculateTokens(systemMessages);
    }

    if (config.preserveSummaryMessages) {
      preservedMessages.addAll(summaryMessages);
      reservedTokens += _calculateTokens(summaryMessages);
    }

    // Calculate available tokens for conversation messages
    final availableTokens = effectiveBudget - reservedTokens;
    if (availableTokens <= 0) {
      // Not enough budget even for preserved messages
      _logger.warning(
        '[$opId] Available tokens ($availableTokens) <= 0 after reserving preserved messages. Returning preserved messages only.',
      );
      sw.stop();
      _logger.fine('[$opId] apply() end - elapsed=${sw.elapsedMilliseconds}ms');
      return StrategyResult(
        included: preservedMessages,
        excluded: conversationMessages,
        summaries: [],
        name: 'SummarizationStrategy',
      );
    }

    // Determine which conversation messages to include/exclude
    final recentMessages = <Message>[];
    final messagesToSummarize = <Message>[];

    // Start from the most recent and work backwards
    int currentTokens = 0;
    int messageCount = 0;

    for (int i = conversationMessages.length - 1; i >= 0; i--) {
      final message = conversationMessages[i];
      final messageTokens = _calculateTokens([message]);

      // Always include minimum recent messages if possible
      if (messageCount < config.minRecentMessages &&
          currentTokens + messageTokens <= availableTokens) {
        recentMessages.insert(0, message);
        currentTokens += messageTokens;
        messageCount++;
        continue;
      }

      // Include additional messages if they fit in budget
      if (currentTokens + messageTokens <= availableTokens) {
        recentMessages.insert(0, message);
        currentTokens += messageTokens;
        messageCount++;
      } else {
        // This message and all older messages need to be summarized
        messagesToSummarize.insertAll(
          0,
          conversationMessages.sublist(0, i + 1),
        );
        break;
      }
    }

    // Generate summaries for excluded messages
    final summaries = <SummaryInfo>[];
    if (messagesToSummarize.isNotEmpty) {
      try {
        final chunkSummaries = await _summarizeInChunks(messagesToSummarize);
        summaries.addAll(chunkSummaries);
      } catch (e, st) {
        // Log and provide a conservative single fallback summary for the whole batch
        _logger.severe(
          '[$opId] _summarizeInChunks failed for ${messagesToSummarize.length} messages',
          e,
          st,
        );
        final fallback = SummaryInfo(
          chunkId: 'fallback_${DateTime.now().microsecondsSinceEpoch}',
          summary:
              'Fallback summary: ${messagesToSummarize.length} messages summarized with reduced fidelity.',
          tokenEstimateBefore: _calculateTokens(messagesToSummarize),
          tokenEstimateAfter: 50,
        );
        summaries.add(fallback);
      }
    }

    // Combine all included messages in proper order
    final includedMessages = <Message>[...preservedMessages, ...recentMessages];

    sw.stop();
    _logger.fine(
      '[$opId] apply() end - included=${includedMessages.length}, excluded=${messagesToSummarize.length}, summaries=${summaries.length}, elapsed=${sw.elapsedMilliseconds}ms',
    );

    return StrategyResult(
      included: includedMessages,
      excluded: messagesToSummarize,
      summaries: summaries,
      name: 'SummarizationStrategy',
    );
  }

  /// Summarize messages in chunks to preserve context better
  Future<List<SummaryInfo>> _summarizeInChunks(List<Message> messages) async {
    final summaries = <SummaryInfo>[];

    // If circuit is open, short-circuit with fallback summaries
    if (_isCircuitOpen()) {
      _logger.warning(
        'Circuit open for summarizer; returning fallback summaries.',
      );
      return messages
          .map((m) => _createFallbackSummary([m]))
          .toList(growable: false);
    }

    const int maxRetries = 2;

    for (int i = 0; i < messages.length; i += config.maxSummaryChunkSize) {
      final chunkEnd = (i + config.maxSummaryChunkSize).clamp(
        0,
        messages.length,
      );
      final chunk = messages.sublist(i, chunkEnd);

      // Validate chunk
      if (chunk.isEmpty) continue;

      SummaryInfo? result;
      int attempt = 0;
      while (attempt <= maxRetries) {
        try {
          final sw = Stopwatch()..start();
          result = await summarizer.summarize(chunk, tokenCounter);
          sw.stop();
          _logger.fine(
            'summarize chunk success size=${chunk.length} elapsed=${sw.elapsedMilliseconds}ms',
          );
          // success: reset failure counter
          _resetFailures();
          break;
        } catch (e, st) {
          attempt++;
          _logger.warning(
            'Summarizer failure on attempt $attempt for chunk size=${chunk.length}: $e',
            e,
            st,
          );

          // on final failure, record failure and possibly open circuit
          if (attempt > maxRetries) {
            _recordFailure();
            _logger.severe(
              'Summarizer failed after $attempt attempts for chunk size=${chunk.length}. Falling back.',
              e,
              st,
            );
            break;
          }

          // Exponential backoff before retrying
          final backoffMs = 100 * (1 << (attempt - 1));
          await Future.delayed(Duration(milliseconds: backoffMs));
        }
      }

      if (result != null) {
        summaries.add(result);
      } else {
        // fallback summary for this chunk
        final fallbackSummary = _createFallbackSummary(chunk);
        summaries.add(fallbackSummary);
      }
    }

    return summaries;
  }

  bool _isCircuitOpen() {
    if (!_circuitOpen) return false;
    final openedAt = _circuitOpenedAt;
    if (openedAt == null) return false;
    final now = DateTime.now();
    if (now.difference(openedAt) > _circuitCooldown) {
      // cooldown passed, close circuit
      _logger.info('Summarizer circuit cooldown passed; closing circuit.');
      _circuitOpen = false;
      _failureCount = 0;
      _circuitOpenedAt = null;
      return false;
    }
    return true;
  }

  void _recordFailure() {
    _failureCount++;
    _logger.warning('Summarizer failure recorded. count=$_failureCount');
    if (_failureCount >= _failureThreshold && !_circuitOpen) {
      _circuitOpen = true;
      _circuitOpenedAt = DateTime.now();
      _logger.warning(
        'Summarizer circuit opened due to repeated failures. threshold=$_failureThreshold',
      );
    }
  }

  void _resetFailures() {
    if (_failureCount > 0) {
      _failureCount = 0;
      _logger.fine(
        'Summarizer failure count reset to 0 after successful operation.',
      );
    }
    if (_circuitOpen) {
      _circuitOpen = false;
      _circuitOpenedAt = null;
      _logger.info('Summarizer circuit closed after successful operation.');
    }
  }

  SummaryInfo _createFallbackSummary(List<Message> chunk) {
    final tokenEstimate = _calculateTokens(chunk);
    final id = 'fallback_${DateTime.now().microsecondsSinceEpoch}';
    _logger.info(
      'Creating fallback summary for chunk size=${chunk.length}, tokens=$tokenEstimate',
    );
    return SummaryInfo(
      chunkId: id,
      summary:
          'Fallback summary of ${chunk.length} messages (${chunk.first.timestamp} to ${chunk.last.timestamp})',
      tokenEstimateBefore: tokenEstimate,
      tokenEstimateAfter: 50,
    );
  }

  /// Calculate token count for a list of messages
  int _calculateTokens(List<Message> messages) {
    final text = messages.map((m) => m.content).join('\n');
    return tokenCounter.estimateTokens(text);
  }
}

/// Factory for creating common summarization strategy configurations
class SummarizationStrategyFactory {
  /// Create a conservative strategy that keeps more recent messages
  static SummarizationStrategy conservative({
    required int maxTokens,
    required Summarizer summarizer,
    required TokenCounter tokenCounter,
  }) {
    return SummarizationStrategy(
      config: SummarizationStrategyConfig(
        maxTokens: maxTokens,
        minRecentMessages: 10,
        maxSummaryChunkSize: 15,
        preserveSystemMessages: true,
        preserveSummaryMessages: true,
      ),
      summarizer: summarizer,
      tokenCounter: tokenCounter,
    );
  }

  /// Create an aggressive strategy that summarizes more aggressively
  static SummarizationStrategy aggressive({
    required int maxTokens,
    required Summarizer summarizer,
    required TokenCounter tokenCounter,
  }) {
    return SummarizationStrategy(
      config: SummarizationStrategyConfig(
        maxTokens: maxTokens,
        minRecentMessages: 3,
        maxSummaryChunkSize: 30,
        preserveSystemMessages: true,
        preserveSummaryMessages: true,
      ),
      summarizer: summarizer,
      tokenCounter: tokenCounter,
    );
  }

  /// Create a balanced strategy with reasonable defaults
  static SummarizationStrategy balanced({
    required int maxTokens,
    required Summarizer summarizer,
    required TokenCounter tokenCounter,
  }) {
    return SummarizationStrategy(
      config: SummarizationStrategyConfig(
        maxTokens: maxTokens,
        minRecentMessages: 5,
        maxSummaryChunkSize: 20,
        preserveSystemMessages: true,
        preserveSummaryMessages: true,
      ),
      summarizer: summarizer,
      tokenCounter: tokenCounter,
    );
  }
}

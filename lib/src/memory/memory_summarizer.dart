import '../core/errors.dart';
import '../core/logging/chat_memory_logger.dart';
import '../core/models/message.dart';
import 'strategies/context_strategy.dart';
import '../core/utils/token_counter.dart';
import 'memory_manager.dart';

/// Manages summarization logic and strategy application
///
/// This class encapsulates all summarization and context strategy logic,
/// making it easier to test and maintain separately from other memory operations.
class MemorySummarizer {
  final ContextStrategy _contextStrategy;
  final TokenCounter _tokenCounter;
  final MemoryConfig _config;
  final _logger = ChatMemoryLogger.loggerFor('memory.summarizer');

  MemorySummarizer({
    required ContextStrategy contextStrategy,
    required TokenCounter tokenCounter,
    required MemoryConfig config,
  }) : _contextStrategy = contextStrategy,
       _tokenCounter = tokenCounter,
       _config = config;

  /// Apply summarization strategy to messages within token budget
  Future<StrategyResult> applySummarization({
    required List<Message> messages,
    required int tokenBudget,
  }) async {
    final opCtx = ErrorContext(
      component: 'MemorySummarizer',
      operation: 'applySummarization',
      params: {'messageCount': messages.length, 'tokenBudget': tokenBudget},
    );

    try {
      _logger.fine('Applying summarization strategy', opCtx.toMap());

      // Apply the configured context strategy
      final result = await _contextStrategy.apply(
        messages: messages,
        tokenBudget: tokenBudget,
        tokenCounter: _tokenCounter,
      );

      _logger.fine('Strategy application completed', {
        ...opCtx.toMap(),
        'includedCount': result.included.length,
        'excludedCount': result.excluded.length,
        'summaryCount': result.summaries.length,
        'strategyName': result.name,
      });

      return result;
    } catch (e, st) {
      ChatMemoryLogger.logError(
        _logger,
        'applySummarization',
        e,
        stackTrace: st,
        params: opCtx.toMap(),
        shouldRethrow: false,
      );
      throw SummarizationException(
        'Failed to apply summarization strategy',
        cause: e,
        stackTrace: st,
        context: opCtx,
      );
    }
  }

  /// Convert summary info objects to message objects with proper metadata
  List<Message> processSummaries(List<SummaryInfo> summaries) {
    final opCtx = ErrorContext(
      component: 'MemorySummarizer',
      operation: 'processSummaries',
      params: {'summaryCount': summaries.length},
    );

    try {
      final summaryMessages = <Message>[];

      for (final summaryInfo in summaries) {
        final summaryMessage = Message(
          id: 'summary_${summaryInfo.chunkId}',
          role: MessageRole.summary,
          content: summaryInfo.summary,
          timestamp: DateTime.now().toUtc(),
          metadata: {
            'chunkId': summaryInfo.chunkId,
            'tokenEstimateBefore': summaryInfo.tokenEstimateBefore,
            'tokenEstimateAfter': summaryInfo.tokenEstimateAfter,
            'compressionRatio': summaryInfo.tokenEstimateBefore > 0
                ? summaryInfo.tokenEstimateAfter /
                      summaryInfo.tokenEstimateBefore
                : 0.0,
          },
        );
        summaryMessages.add(summaryMessage);
      }

      _logger.fine('Processed summaries into messages', {
        ...opCtx.toMap(),
        'processedCount': summaryMessages.length,
      });

      return summaryMessages;
    } catch (e, st) {
      ChatMemoryLogger.logError(
        _logger,
        'processSummaries',
        e,
        stackTrace: st,
        params: opCtx.toMap(),
        shouldRethrow: false,
      );
      throw SummarizationException(
        'Failed to process summaries',
        cause: e,
        stackTrace: st,
        context: opCtx,
      );
    }
  }

  /// Calculate total token count for a list of messages
  int calculateTokens(List<Message> messages) {
    if (messages.isEmpty) return 0;

    try {
      return messages.fold<int>(
        0,
        (sum, message) => sum + _tokenCounter.estimateTokens(message.content),
      );
    } catch (e) {
      _logger.warning('Error calculating tokens, returning 0', {
        'error': e.toString(),
        'messageCount': messages.length,
      });
      return 0;
    }
  }

  /// Get the name of the current context strategy
  String get strategyName => _contextStrategy.runtimeType.toString();

  /// Check if summarization is enabled in the configuration
  bool get isSummarizationEnabled => _config.enableSummarization;
}

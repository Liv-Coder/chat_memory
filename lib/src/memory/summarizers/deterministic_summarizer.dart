import 'summarizer.dart';
import '../../core/models/message.dart';
import '../strategies/context_strategy.dart';
import '../../core/utils/token_counter.dart';

import '../../core/errors.dart';
import '../../core/logging/chat_memory_logger.dart';

/// Simple deterministic summarizer: join messages and truncate to a target char length.
/// Adds validation, logging and error handling to be production-safe.
class DeterministicSummarizer implements Summarizer {
  final int maxChars;
  final _logger = ChatMemoryLogger.loggerFor('summarizers.deterministic');

  DeterministicSummarizer({this.maxChars = 200}) {
    // Validate constructor parameters
    Validation.validatePositive(
      'maxChars',
      maxChars,
      context: ErrorContext(
        component: 'DeterministicSummarizer',
        operation: 'constructor',
      ),
    );
  }

  @override
  Future<SummaryInfo> summarize(
    List<Message> messages,
    TokenCounter tokenCounter,
  ) async {
    final ctx = ErrorContext(
      component: 'DeterministicSummarizer',
      operation: 'summarize',
      params: {'count': messages.length, 'maxChars': maxChars},
    );

    try {
      // Handle empty input gracefully
      if (messages.isEmpty) {
        _logger.warning(
          'summarize called with empty messages list; returning empty summary.',
        );
        return SummaryInfo(
          chunkId: DateTime.now().microsecondsSinceEpoch.toString(),
          summary: '',
          tokenEstimateBefore: 0,
          tokenEstimateAfter: 0,
        );
      }

      // Validate inputs
      Validation.validateListNotEmpty('messages', messages, context: ctx);

      final combined = messages.map((m) => m.content).join(' ');
      final before = tokenCounter.estimateTokens(combined);

      final summary = combined.length > maxChars
          ? '${combined.substring(0, maxChars)}…'
          : combined;

      final after = tokenCounter.estimateTokens(summary);

      // Basic quality check
      if (summary.trim().isEmpty) {
        _logger.warning(
          'Generated summary is empty after processing; returning minimal summary.',
        );
        return SummaryInfo(
          chunkId: DateTime.now().microsecondsSinceEpoch.toString(),
          summary: combined.substring(0, maxChars.clamp(0, combined.length)),
          tokenEstimateBefore: before,
          tokenEstimateAfter: tokenCounter.estimateTokens(
            combined.substring(0, maxChars.clamp(0, combined.length)),
          ),
        );
      }

      _logger.fine(
        'Deterministic summary created size=${summary.length} beforeTokens=$before afterTokens=$after',
      );

      return SummaryInfo(
        chunkId: DateTime.now().microsecondsSinceEpoch.toString(),
        summary: summary,
        tokenEstimateBefore: before,
        tokenEstimateAfter: after,
      );
    } catch (e, st) {
      _logger.severe('DeterministicSummarizer.summarize failed', e, st);
      throw SummarizationException(
        'DeterministicSummarizer failed to summarize messages',
        cause: e,
        stackTrace: st,
        context: ctx,
      );
    }
  }
}

import '../models/message.dart';
import '../utils/token_counter.dart';
import '../summarizers/summarizer.dart';
import 'context_strategy.dart';

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

  SummarizationStrategy({
    required this.config,
    required this.summarizer,
    required this.tokenCounter,
  });

  @override
  Future<StrategyResult> apply({
    required List<Message> messages,
    required int tokenBudget,
    required TokenCounter tokenCounter,
  }) async {
    if (messages.isEmpty) {
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
      final chunkSummaries = await _summarizeInChunks(messagesToSummarize);
      summaries.addAll(chunkSummaries);
    }

    // Combine all included messages in proper order
    final includedMessages = <Message>[...preservedMessages, ...recentMessages];

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

    for (int i = 0; i < messages.length; i += config.maxSummaryChunkSize) {
      final chunkEnd = (i + config.maxSummaryChunkSize).clamp(
        0,
        messages.length,
      );
      final chunk = messages.sublist(i, chunkEnd);

      try {
        final summary = await summarizer.summarize(chunk, tokenCounter);
        summaries.add(summary);
      } catch (e) {
        // If summarization fails, create a simple fallback summary
        final fallbackSummary = SummaryInfo(
          chunkId: 'chunk_${DateTime.now().microsecondsSinceEpoch}',
          summary:
              'Summary of ${chunk.length} messages (${chunk.first.timestamp} to ${chunk.last.timestamp})',
          tokenEstimateBefore: _calculateTokens(chunk),
          tokenEstimateAfter: 50, // Conservative estimate for fallback
        );
        summaries.add(fallbackSummary);
      }
    }

    return summaries;
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

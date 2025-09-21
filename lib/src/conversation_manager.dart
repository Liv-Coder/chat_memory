import 'models/message.dart';
import 'models/prompt_payload.dart';
import 'persistence/persistence_strategy.dart';
import 'persistence/in_memory_store.dart';
import 'strategies/context_strategy.dart';
import 'strategies/sliding_window_strategy.dart';
import 'utils/token_counter.dart';
import 'follow_up/follow_up_generator.dart';
import 'summarizers/summarizer.dart';
import 'summarizers/deterministic_summarizer.dart';
import 'summarizers/summarization_config.dart';

/// Orchestrates conversation memory: persists messages, applies strategies,
/// runs summarizers, and builds `PromptPayload` objects ready to send to an LLM.
class ConversationManager {
  PersistenceStrategy _persistence;
  ContextStrategy _strategy;
  TokenCounter _tokenCounter;
  Summarizer? _summarizer;
  SummarizationConfig? _summarizationConfig;
  void Function(Message)? _onSummaryCreated;
  FollowUpGenerator? _followUpGenerator;

  ConversationManager({
    PersistenceStrategy? persistence,
    ContextStrategy? strategy,
    TokenCounter? tokenCounter,
    Summarizer? summarizer,
    SummarizationConfig? summarizationConfig,
    void Function(Message)? onSummaryCreated,
    FollowUpGenerator? followUpGenerator,
  }) : _persistence = persistence ?? InMemoryStore(),
       _strategy = strategy ?? SlidingWindowStrategy(),
       _tokenCounter = tokenCounter ?? HeuristicTokenCounter(),
       _summarizer = summarizer,
       _summarizationConfig = summarizationConfig,
       _onSummaryCreated = onSummaryCreated,
       _followUpGenerator = followUpGenerator;

  Future<void> appendMessage(Message message) async {
    await _persistence.saveMessages([message]);
  }

  Future<void> appendUserMessage(
    String content, {
    Map<String, dynamic>? metadata,
  }) async {
    final m = Message(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      role: MessageRole.user,
      content: content,
      timestamp: DateTime.now().toUtc(),
      metadata: metadata,
    );
    await appendMessage(m);
  }

  Future<void> appendAssistantMessage(
    String content, {
    Map<String, dynamic>? metadata,
  }) async {
    final m = Message(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      role: MessageRole.assistant,
      content: content,
      timestamp: DateTime.now().toUtc(),
      metadata: metadata,
    );
    await appendMessage(m);
  }

  void registerSummarizer(Summarizer summarizer) {
    _summarizer = summarizer;
  }

  /// Register a default deterministic summarizer with optional char limit.
  void registerDefaultDeterministicSummarizer({int maxChars = 200}) {
    _summarizer = DeterministicSummarizer(maxChars: maxChars);
  }

  void setStrategy(ContextStrategy strategy) {
    _strategy = strategy;
  }

  /// Register a follow-up generator (pluggable).
  void registerFollowUpGenerator(FollowUpGenerator generator) {
    _followUpGenerator = generator;
  }

  /// Generate context-aware follow-up questions using the registered generator.
  /// Returns an empty list if no generator is registered or generation fails.
  Future<List<String>> generateFollowUpQuestions({int max = 3}) async {
    if (_followUpGenerator == null) return [];
    try {
      final messages = await _persistence.loadMessages();
      return await _followUpGenerator!.generate(messages, max: max);
    } catch (_) {
      return [];
    }
  }

  // Safe lookup helpers (avoid using firstWhere/orElse that must return non-null)
  Message? _findFirstByRole(List<Message> messages, MessageRole role) {
    for (var m in messages) {
      if (m.role == role) return m;
    }
    return null;
  }

  Message? _findLastByRole(List<Message> messages, MessageRole role) {
    for (var i = messages.length - 1; i >= 0; i--) {
      if (messages[i].role == role) return messages[i];
    }
    return null;
  }

  Future<PromptPayload> buildPrompt({
    required int clientTokenBudget,
    bool trace = false,
  }) async {
    final messages = await _persistence.loadMessages();

    // Identify system and existing summary messages (if any)
    final Message? systemMessage = _findFirstByRole(
      messages,
      MessageRole.system,
    );
    final Message? existingSummaryMessage = _findLastByRole(
      messages,
      MessageRole.summary,
    );

    // Pre-check: estimate tokens for entire conversation
    final allText = messages.map((m) => m.content).join('\n');
    final totalTokens = _tokenCounter.estimateTokens(allText);

    // If within budget, return messages untouched (preserve chronological order)
    if (totalTokens <= clientTokenBudget) {
      final promptText = messages
          .map((m) => '${m.role.toString().split('.').last}: ${m.content}')
          .join('\n');
      final estimated = _tokenCounter.estimateTokens(promptText);
      final inclusionTrace = InclusionTrace(
        selectedMessageIds: messages.map((m) => m.id).toList(),
        excludedReasons: {},
        summaries: [],
        strategyUsed: 'NoSummarization_PreCheck',
      );
      return PromptPayload(
        promptText: promptText,
        includedMessages: messages,
        summary: null,
        estimatedTokens: estimated,
        trace: inclusionTrace,
      );
    }

    // Otherwise, apply strategy to decide included/excluded messages
    final strategyResult = await _strategy.apply(
      messages: messages,
      tokenBudget: clientTokenBudget,
      tokenCounter: _tokenCounter,
    );

    final included = strategyResult.included;
    final excluded = strategyResult.excluded;
    final summaries = List<SummaryInfo>.from(strategyResult.summaries);

    // Decide which messages to summarize based on SummarizationConfig.
    // Default: summarize all excluded messages.
    List<Message> messagesToSummarize = excluded;
    if (_summarizationConfig != null) {
      final cfg = _summarizationConfig!;
      // Ensure excluded messages are ordered oldest -> newest for selection logic.
      final excludedOrdered = List<Message>.from(excluded.reversed);

      switch (cfg.mode) {
        case SummarizationMode.oldestFirst:
          final retainCount =
              (excludedOrdered.length * cfg.recentMessageRetentionRatio).ceil();
          var toSummarizeCount = excludedOrdered.length - retainCount;
          if (toSummarizeCount <= 0 && excludedOrdered.isNotEmpty) {
            toSummarizeCount = 1;
          }
          messagesToSummarize = excludedOrdered.sublist(
            0,
            toSummarizeCount.clamp(0, excludedOrdered.length),
          );
          break;

        case SummarizationMode.chunked:
          var n = cfg.chunkSize;
          if (n < 1) n = 1;
          if (n > excludedOrdered.length) n = excludedOrdered.length;
          messagesToSummarize = excludedOrdered.sublist(0, n);
          break;

        case SummarizationMode.layered:
          // For layered mode, include any existing summary message first, then
          // add a block of the oldest excluded messages to summarize together.
          final parts = <Message>[];
          if (existingSummaryMessage != null) {
            parts.add(existingSummaryMessage);
          }
          if (excludedOrdered.isNotEmpty) {
            var m = cfg.chunkSize;
            if (m < 1) m = 1;
            if (m > excludedOrdered.length) m = excludedOrdered.length;
            parts.addAll(excludedOrdered.sublist(0, m));
          }
          messagesToSummarize = parts;
          break;
      }
    }

    SummaryInfo? generatedSummary;
    Message? newSummaryMessage;

    if (_summarizer != null && messagesToSummarize.isNotEmpty) {
      generatedSummary = await _summarizer!.summarize(
        messagesToSummarize,
        _tokenCounter,
      );

      // Construct summary message with metadata
      newSummaryMessage = Message(
        id: generatedSummary.chunkId,
        role: MessageRole.summary,
        content: generatedSummary.summary,
        timestamp: DateTime.now().toUtc(),
        metadata: {
          'tokenEstimateBefore': generatedSummary.tokenEstimateBefore,
          'tokenEstimateAfter': generatedSummary.tokenEstimateAfter,
        },
      );

      // Persist the summary into the conversation store
      await _persistence.saveMessages([newSummaryMessage]);

      // Attach to summaries trace
      summaries.add(generatedSummary);

      // onSummaryCreated hook
      if (_onSummaryCreated != null) {
        try {
          _onSummaryCreated!(newSummaryMessage);
        } catch (_) {
          // swallow callback errors to avoid breaking flow
        }
      }
    }

    // Reconstruct final prompt: systemMessage, newSummaryMessage (if any), then included messages.
    final finalParts = <Message>[];
    if (systemMessage != null) finalParts.add(systemMessage);
    if (newSummaryMessage != null) finalParts.add(newSummaryMessage);
    finalParts.addAll(included);

    final promptText = finalParts
        .map((m) => '${m.role.toString().split('.').last}: ${m.content}')
        .join('\n');
    final estimated = _tokenCounter.estimateTokens(promptText);

    final inclusionTrace = InclusionTrace(
      selectedMessageIds: included.map((m) => m.id).toList(),
      excludedReasons: {for (var e in excluded) e.id: 'excluded_by_strategy'},
      summaries: summaries
          .map(
            (s) => {
              'chunkId': s.chunkId,
              'summary': s.summary,
              'before': s.tokenEstimateBefore,
              'after': s.tokenEstimateAfter,
            },
          )
          .toList(),
      strategyUsed: strategyResult.name,
    );

    return PromptPayload(
      promptText: promptText,
      includedMessages: included,
      summary: generatedSummary?.summary,
      estimatedTokens: estimated,
      trace: inclusionTrace,
    );
  }

  Future<void> flush() async {
    // If persistence requires flush semantics, implement here.
  }
}

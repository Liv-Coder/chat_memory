import 'models/message.dart';
import 'models/prompt_payload.dart';
import 'persistence/persistence_strategy.dart';
import 'persistence/in_memory_store.dart';
import 'strategies/context_strategy.dart';
import 'strategies/sliding_window_strategy.dart';
import 'utils/token_counter.dart';
import 'summarizers/summarizer.dart';
import 'summarizers/deterministic_summarizer.dart';

class ConversationManager {
  PersistenceStrategy _persistence;
  ContextStrategy _strategy;
  TokenCounter _tokenCounter;
  Summarizer? _summarizer;

  ConversationManager({
    PersistenceStrategy? persistence,
    ContextStrategy? strategy,
    TokenCounter? tokenCounter,
  }) : _persistence = persistence ?? InMemoryStore(),
       _strategy = strategy ?? SlidingWindowStrategy(),
       _tokenCounter = tokenCounter ?? HeuristicTokenCounter();

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

  Future<PromptPayload> buildPrompt({
    required int clientTokenBudget,
    bool trace = false,
  }) async {
    final messages = await _persistence.loadMessages();
    final strategyResult = await _strategy.apply(
      messages: messages,
      tokenBudget: clientTokenBudget,
      tokenCounter: _tokenCounter,
    );

    final included = strategyResult.included;

    final promptText = included
        .map((m) => '${m.role.toString().split('.').last}: ${m.content}')
        .join('\n');
    final estimated = _tokenCounter.estimateTokens(promptText);

    final inclusionTrace = InclusionTrace(
      selectedMessageIds: included.map((m) => m.id).toList(),
      excludedReasons: {
        for (var e in strategyResult.excluded) e.id: 'excluded_by_strategy',
      },
      summaries: strategyResult.summaries
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

    String? summaryText;

    // If a summarizer is registered and there are excluded messages, summarize them.
    if (_summarizer != null && strategyResult.excluded.isNotEmpty) {
      final summary = await _summarizer!.summarize(
        strategyResult.excluded,
        _tokenCounter,
      );
      summaryText = summary.summary;
      // Add the generated summary into the trace summaries as well.
      inclusionTrace.summaries.add({
        'chunkId': summary.chunkId,
        'summary': summary.summary,
        'before': summary.tokenEstimateBefore,
        'after': summary.tokenEstimateAfter,
      });
    }

    return PromptPayload(
      promptText: promptText,
      includedMessages: included,
      summary: summaryText,
      estimatedTokens: estimated,
      trace: inclusionTrace,
    );
  }

  Future<void> flush() async {
    // If persistence requires flush semantics, implement here.
  }
}

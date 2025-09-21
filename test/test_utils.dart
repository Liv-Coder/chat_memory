import 'package:chat_memory/src/core/models/message.dart';
import 'package:chat_memory/src/memory/vector_stores/vector_store.dart';
import 'package:chat_memory/src/memory/strategies/context_strategy.dart';
import 'package:chat_memory/src/core/utils/token_counter.dart';

/// Shared test utilities for unit and integration tests.

class TestMessageFactory {
  static int _counter = 0;

  /// Create a message with a predictable id, content and timestamp.
  static Message create({
    MessageRole role = MessageRole.user,
    String? content,
    DateTime? timestamp,
    Map<String, dynamic>? metadata,
  }) {
    final id = 'msg_${++_counter}';
    final ts =
        timestamp ?? DateTime.utc(2020, 1, 1).add(Duration(seconds: _counter));
    return Message(
      id: id,
      role: role,
      content: content ?? 'content_for_$id',
      timestamp: ts.toUtc(),
      metadata: metadata,
    );
  }

  /// Generate a list of test messages ordered oldest -> newest.
  static List<Message> createTestMessages(
    int count, {
    MessageRole role = MessageRole.user,
  }) {
    _counter = 0;
    return List.generate(count, (i) {
      return create(
        role: role,
        content: 'message_${i + 1}',
        timestamp: DateTime.utc(2020, 1, 1).add(Duration(seconds: i)),
      );
    });
  }
}

/// Create a deterministic test vector entry with known embedding values.
VectorEntry createTestVectorEntry({
  String id = 'vec_1',
  int dim = 4,
  String content = 'test content',
  Map<String, dynamic>? metadata,
  DateTime? timestamp,
}) {
  final embedding = List<double>.generate(dim, (i) => i == 0 ? 1.0 : 0.0);
  return VectorEntry(
    id: id,
    embedding: embedding,
    content: content,
    metadata: {'role': 'user', 'test': true, ...?metadata},
    timestamp: (timestamp ?? DateTime.utc(2020, 1, 1)).toUtc(),
  );
}

/// Fake context strategy with configurable behavior for tests.
///
/// By default it includes the first [includeCount] messages and marks others
/// as excluded. If [includeAll] is true then all messages are included.
class FakeContextStrategy implements ContextStrategy {
  final bool includeAll;
  final int? includeCount;
  final String name;

  FakeContextStrategy({
    this.includeAll = false,
    this.includeCount,
    this.name = 'fake',
  });

  @override
  Future<StrategyResult> apply({
    required List<Message> messages,
    required int tokenBudget,
    required TokenCounter tokenCounter,
  }) async {
    if (includeAll) {
      return StrategyResult(
        included: List<Message>.from(messages),
        excluded: const [],
        summaries: const [],
        name: name,
      );
    }

    final count =
        includeCount ??
        (messages.length <= tokenBudget ? messages.length : tokenBudget);
    final included = messages.take(count).toList();
    final excluded = messages.skip(count).toList();

    // Produce a trivial summary for excluded chunks to satisfy tests.
    final summaries = <SummaryInfo>[];
    if (excluded.isNotEmpty) {
      summaries.add(
        SummaryInfo(
          chunkId: 'chunk_0',
          summary: 'summary_of_${excluded.length}_messages',
          tokenEstimateBefore: excluded.fold(
            0,
            (s, m) => s + tokenCounter.estimateTokens(m.content),
          ),
          tokenEstimateAfter: 1,
        ),
      );
    }

    return StrategyResult(
      included: included,
      excluded: excluded,
      summaries: summaries,
      name: name,
    );
  }
}

/// Fake token counter with predictable, stable behavior for tests.
///
/// It estimates tokens by dividing characters by [charsPerToken] and optionally
/// adding a fixed offset.
class FakeTokenCounter implements TokenCounter {
  final int charsPerToken;
  final int offset;

  FakeTokenCounter({this.charsPerToken = 4, this.offset = 0})
    : assert(charsPerToken > 0);

  @override
  int estimateTokens(String text) {
    if (text.isEmpty) return offset;
    final normalized = text.replaceAll(RegExp(r"\s+"), ' ');
    final chars = normalized.length;
    return (chars / charsPerToken).ceil() + offset;
  }
}

/// Common constants used across tests.
class TestConstants {
  static const List<double> sampleEmbeddingSmall = [1.0, 0.0, 0.0, 0.0];
  static const List<double> sampleEmbeddingUnit = [
    0.57735026919,
    0.57735026919,
    0.57735026919,
  ];
  static const double sampleSimilarityHigh = 0.95;
  static const double sampleSimilarityLow = 0.1;
  static const int defaultTokenEstimate = 4;
}

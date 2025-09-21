import 'core/models/prompt_payload.dart';
import 'core/models/message.dart';
import 'memory/memory_manager.dart';

/// Simplified result object for context retrieval operations.
///
/// Provides a clean, user-friendly interface to access conversation context
/// while hiding the complexity of `PromptPayload` and `MemoryContextResult`.
///
/// Example usage:
/// ```dart
/// final context = await chatMemory.getContext(query: 'What did we discuss?');
///
/// print('Context ready: ${context.promptText}');
/// print('Messages included: ${context.messageCount}');
/// print('Within token limit: ${context.isWithinTokenLimit(4000)}');
///
/// if (context.hasMemory) {
///   print('Summary available: ${context.hasSummary}');
/// }
/// ```
class ChatContext {
  /// The final prompt text ready to send to an LLM.
  final String promptText;

  /// Number of messages included in the context.
  final int messageCount;

  /// Whether semantic memory retrieval was used.
  final bool hasMemory;

  /// Estimated token count for the prompt.
  final int estimatedTokens;

  /// Whether a summary was generated and included.
  final bool hasSummary;

  /// The summary text if available.
  final String? summaryText;

  /// Messages included in the final context.
  final List<Message> includedMessages;

  /// Strategy used for message selection (e.g., 'SlidingWindow', 'Summarization').
  final String strategyUsed;

  /// Timestamp when this context was generated.
  final DateTime timestamp;

  /// Error information if context retrieval encountered issues.
  final String? error;

  /// Performance metrics for context generation.
  final Map<String, dynamic>? metrics;

  /// Creates a new ChatContext with the specified properties.
  const ChatContext({
    required this.promptText,
    required this.messageCount,
    required this.hasMemory,
    required this.estimatedTokens,
    required this.hasSummary,
    this.summaryText,
    required this.includedMessages,
    required this.strategyUsed,
    required this.timestamp,
    this.error,
    this.metrics,
  });

  /// Creates a ChatContext from a PromptPayload.
  factory ChatContext.fromPromptPayload(PromptPayload payload) {
    return ChatContext(
      promptText: payload.promptText,
      messageCount: payload.includedMessages.length,
      hasMemory: true, // PromptPayload implies memory was used
      estimatedTokens: payload.estimatedTokens,
      hasSummary: payload.summary != null,
      summaryText: payload.summary,
      includedMessages: List.unmodifiable(payload.includedMessages),
      strategyUsed: payload.trace.strategyUsed,
      timestamp: payload.trace.timestamp,
    );
  }

  /// Creates a ChatContext from a MemoryContextResult.
  factory ChatContext.fromMemoryResult(MemoryContextResult result) {
    return ChatContext(
      promptText: result.messages.map((m) => m.content).join('\n'),
      messageCount: result.messages.length,
      hasMemory: true,
      estimatedTokens: result.estimatedTokens,
      hasSummary: result.summary != null,
      summaryText: result.summary,
      includedMessages: List.unmodifiable(result.messages),
      strategyUsed: result.metadata['strategyUsed']?.toString() ?? 'Unknown',
      timestamp: DateTime.now().toUtc(),
      metrics: result.metadata,
    );
  }

  /// Creates a simple ChatContext for basic scenarios without memory.
  factory ChatContext.simple({
    required String promptText,
    required List<Message> messages,
    int? estimatedTokens,
  }) {
    return ChatContext(
      promptText: promptText,
      messageCount: messages.length,
      hasMemory: false,
      estimatedTokens:
          estimatedTokens ?? promptText.length ~/ 4, // Rough estimate
      hasSummary: false,
      includedMessages: List.unmodifiable(messages),
      strategyUsed: 'Simple',
      timestamp: DateTime.now().toUtc(),
    );
  }

  /// Creates an error ChatContext when context retrieval fails.
  factory ChatContext.error({
    required String error,
    String? partialPrompt,
    List<Message>? availableMessages,
  }) {
    return ChatContext(
      promptText: partialPrompt ?? '',
      messageCount: availableMessages?.length ?? 0,
      hasMemory: false,
      estimatedTokens: 0,
      hasSummary: false,
      includedMessages: List.unmodifiable(availableMessages ?? []),
      strategyUsed: 'Error',
      timestamp: DateTime.now().toUtc(),
      error: error,
    );
  }

  /// Returns true if the context is empty (no prompt text).
  bool get isEmpty => promptText.trim().isEmpty;

  /// Returns true if the context has content.
  bool get isNotEmpty => !isEmpty;

  /// Returns true if the estimated tokens are within the specified limit.
  bool isWithinTokenLimit(int tokenLimit) => estimatedTokens <= tokenLimit;

  /// Returns true if this context represents an error state.
  bool get hasError => error != null;

  /// Returns a list of message IDs included in the context.
  List<String> get messageIds => includedMessages.map((m) => m.id).toList();

  /// Returns the most recent message in the context, if any.
  Message? get lastMessage {
    return includedMessages.isNotEmpty ? includedMessages.last : null;
  }

  /// Returns the oldest message in the context, if any.
  Message? get firstMessage {
    return includedMessages.isNotEmpty ? includedMessages.first : null;
  }

  /// Returns messages filtered by role.
  List<Message> getMessagesByRole(MessageRole role) {
    return includedMessages.where((m) => m.role == role).toList();
  }

  /// Returns a brief summary of the context for logging.
  String get summary {
    if (hasError) return 'Error: $error';
    return 'Context: $messageCount messages, $estimatedTokens tokens, strategy: $strategyUsed';
  }

  /// Creates a copy of this context with updated properties.
  ChatContext copyWith({
    String? promptText,
    int? messageCount,
    bool? hasMemory,
    int? estimatedTokens,
    bool? hasSummary,
    String? summaryText,
    List<Message>? includedMessages,
    String? strategyUsed,
    DateTime? timestamp,
    String? error,
    Map<String, dynamic>? metrics,
  }) {
    return ChatContext(
      promptText: promptText ?? this.promptText,
      messageCount: messageCount ?? this.messageCount,
      hasMemory: hasMemory ?? this.hasMemory,
      estimatedTokens: estimatedTokens ?? this.estimatedTokens,
      hasSummary: hasSummary ?? this.hasSummary,
      summaryText: summaryText ?? this.summaryText,
      includedMessages: includedMessages ?? this.includedMessages,
      strategyUsed: strategyUsed ?? this.strategyUsed,
      timestamp: timestamp ?? this.timestamp,
      error: error ?? this.error,
      metrics: metrics ?? this.metrics,
    );
  }

  /// Converts this context to JSON for serialization.
  Map<String, dynamic> toJson() {
    return {
      'promptText': promptText,
      'messageCount': messageCount,
      'hasMemory': hasMemory,
      'estimatedTokens': estimatedTokens,
      'hasSummary': hasSummary,
      'summaryText': summaryText,
      'strategyUsed': strategyUsed,
      'timestamp': timestamp.toUtc().toIso8601String(),
      'error': error,
      'metrics': metrics,
      'messageIds': messageIds,
    };
  }

  /// Creates a ChatContext from JSON data.
  factory ChatContext.fromJson(Map<String, dynamic> json) {
    return ChatContext(
      promptText: json['promptText'] as String? ?? '',
      messageCount: json['messageCount'] as int? ?? 0,
      hasMemory: json['hasMemory'] as bool? ?? false,
      estimatedTokens: json['estimatedTokens'] as int? ?? 0,
      hasSummary: json['hasSummary'] as bool? ?? false,
      summaryText: json['summaryText'] as String?,
      includedMessages: const [], // Messages not serialized in simple JSON
      strategyUsed: json['strategyUsed'] as String? ?? 'Unknown',
      timestamp: DateTime.parse(
        json['timestamp'] as String? ??
            DateTime.now().toUtc().toIso8601String(),
      ),
      error: json['error'] as String?,
      metrics: json['metrics'] as Map<String, dynamic>?,
    );
  }

  @override
  String toString() {
    final buffer = StringBuffer('ChatContext(');
    buffer.write('messages: $messageCount, ');
    buffer.write('tokens: $estimatedTokens, ');
    buffer.write('strategy: $strategyUsed');

    if (hasMemory) buffer.write(', hasMemory');
    if (hasSummary) buffer.write(', hasSummary');
    if (hasError) buffer.write(', error: $error');

    buffer.write(')');
    return buffer.toString();
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ChatContext &&
        other.promptText == promptText &&
        other.messageCount == messageCount &&
        other.hasMemory == hasMemory &&
        other.estimatedTokens == estimatedTokens &&
        other.hasSummary == hasSummary &&
        other.summaryText == summaryText &&
        other.strategyUsed == strategyUsed &&
        other.timestamp == timestamp &&
        other.error == error;
  }

  @override
  int get hashCode {
    return Object.hash(
      promptText,
      messageCount,
      hasMemory,
      estimatedTokens,
      hasSummary,
      summaryText,
      strategyUsed,
      timestamp,
      error,
    );
  }
}

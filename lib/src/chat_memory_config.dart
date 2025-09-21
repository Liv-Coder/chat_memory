import 'memory/hybrid_memory_factory.dart';
import 'core/errors.dart';

/// Preset configurations for ChatMemory with optimized defaults.
enum ChatMemoryPreset {
  /// Development preset with fast setup and debugging features.
  /// - In-memory storage
  /// - Lower token limits for faster processing
  /// - Enhanced logging
  development,

  /// Production preset with persistent storage and optimized performance.
  /// - Local vector store persistence
  /// - Higher token limits
  /// - Optimized for throughput
  production,

  /// Minimal preset with basic functionality and lowest resource usage.
  /// - Minimal memory footprint
  /// - Basic summarization
  /// - Essential features only
  minimal,
}

/// Simplified configuration for ChatMemory instances.
///
/// Provides a declarative way to configure ChatMemory behavior while hiding
/// the complexity of underlying memory management, vector stores, and processing
/// strategies.
///
/// Example usage:
/// ```dart
/// // Using presets
/// final config = ChatMemoryConfig.development();
/// final config = ChatMemoryConfig.production();
///
/// // Custom configuration
/// final config = ChatMemoryConfig(
///   preset: ChatMemoryPreset.development,
///   maxTokens: 2000,
///   enableMemory: true,
///   useSystemPrompt: true,
///   systemPrompt: 'You are a helpful assistant.',
/// );
/// ```
class ChatMemoryConfig {
  /// Default system prompt that provides friendly, helpful behavior.
  static const String defaultSystemPrompt =
      "You are a friendly and helpful assistant. Respond in a natural, "
      "human-like manner. Keep answers clear, concise, and context-aware.";

  /// The preset configuration to use as a base.
  final ChatMemoryPreset preset;

  /// Maximum number of tokens allowed in the context.
  final int maxTokens;

  /// Whether to enable semantic memory and retrieval.
  final bool enableMemory;

  /// Whether to enable conversation summarization.
  final bool enableSummarization;

  /// Whether to enable detailed logging.
  final bool enableLogging;

  /// Whether to persist data to storage.
  final bool enablePersistence;

  /// Whether to automatically inject a system prompt.
  final bool useSystemPrompt;

  /// Custom system prompt text. If null, uses [defaultSystemPrompt].
  final String? systemPrompt;

  /// Creates a new ChatMemoryConfig with the specified settings.
  const ChatMemoryConfig({
    required this.preset,
    this.maxTokens = 4000,
    this.enableMemory = true,
    this.enableSummarization = true,
    this.enableLogging = true,
    this.enablePersistence = false,
    this.useSystemPrompt = true,
    this.systemPrompt,
  });

  /// Creates a development configuration optimized for fast iteration.
  factory ChatMemoryConfig.development() {
    return const ChatMemoryConfig(
      preset: ChatMemoryPreset.development,
      maxTokens: 2000,
      enableMemory: true,
      enableSummarization: true,
      enableLogging: true,
      enablePersistence: false,
      useSystemPrompt: true,
    );
  }

  /// Creates a production configuration optimized for performance and reliability.
  factory ChatMemoryConfig.production() {
    return const ChatMemoryConfig(
      preset: ChatMemoryPreset.production,
      maxTokens: 8000,
      enableMemory: true,
      enableSummarization: true,
      enableLogging: false,
      enablePersistence: true,
      useSystemPrompt: true,
    );
  }

  /// Creates a minimal configuration with basic functionality only.
  factory ChatMemoryConfig.minimal() {
    return const ChatMemoryConfig(
      preset: ChatMemoryPreset.minimal,
      maxTokens: 1000,
      enableMemory: false,
      enableSummarization: false,
      enableLogging: false,
      enablePersistence: false,
      useSystemPrompt: false,
    );
  }

  /// Creates a copy of this config with the specified changes.
  ChatMemoryConfig copyWith({
    ChatMemoryPreset? preset,
    int? maxTokens,
    bool? enableMemory,
    bool? enableSummarization,
    bool? enableLogging,
    bool? enablePersistence,
    bool? useSystemPrompt,
    String? systemPrompt,
  }) {
    return ChatMemoryConfig(
      preset: preset ?? this.preset,
      maxTokens: maxTokens ?? this.maxTokens,
      enableMemory: enableMemory ?? this.enableMemory,
      enableSummarization: enableSummarization ?? this.enableSummarization,
      enableLogging: enableLogging ?? this.enableLogging,
      enablePersistence: enablePersistence ?? this.enablePersistence,
      useSystemPrompt: useSystemPrompt ?? this.useSystemPrompt,
      systemPrompt: systemPrompt ?? this.systemPrompt,
    );
  }

  /// Validates the configuration and throws if invalid.
  void validate() {
    if (maxTokens <= 0) {
      throw ConfigurationException.invalid(
        'maxTokens',
        'must be greater than 0',
        context: ErrorContext(
          component: 'ChatMemoryConfig',
          operation: 'validate',
          params: {'maxTokens': maxTokens},
        ),
      );
    }

    if (maxTokens > 100000) {
      throw ConfigurationException.invalid(
        'maxTokens',
        'cannot exceed 100,000 for performance reasons',
        context: ErrorContext(
          component: 'ChatMemoryConfig',
          operation: 'validate',
          params: {'maxTokens': maxTokens},
        ),
      );
    }

    // Validate system prompt configuration
    if (useSystemPrompt) {
      final prompt = systemPrompt ?? defaultSystemPrompt;
      if (prompt.isEmpty) {
        throw ConfigurationException.invalid(
          'systemPrompt',
          'cannot be empty when useSystemPrompt is true',
          context: ErrorContext(
            component: 'ChatMemoryConfig',
            operation: 'validate',
            params: {
              'useSystemPrompt': useSystemPrompt,
              'systemPrompt': systemPrompt,
            },
          ),
        );
      }

      if (prompt.length > 5000) {
        throw ConfigurationException.invalid(
          'systemPrompt',
          'cannot exceed 5,000 characters for performance reasons',
          context: ErrorContext(
            component: 'ChatMemoryConfig',
            operation: 'validate',
            params: {'systemPromptLength': prompt.length},
          ),
        );
      }
    }
  }

  /// Converts this configuration to a MemoryPreset for the HybridMemoryFactory.
  MemoryPreset toMemoryPreset() {
    switch (preset) {
      case ChatMemoryPreset.development:
        return MemoryPreset.development;
      case ChatMemoryPreset.production:
        return MemoryPreset.production;
      case ChatMemoryPreset.minimal:
        return MemoryPreset.minimal;
    }
  }

  /// Converts this configuration to JSON for serialization.
  Map<String, dynamic> toJson() {
    return {
      'preset': preset.name,
      'maxTokens': maxTokens,
      'enableMemory': enableMemory,
      'enableSummarization': enableSummarization,
      'enableLogging': enableLogging,
      'enablePersistence': enablePersistence,
      'useSystemPrompt': useSystemPrompt,
      'systemPrompt': systemPrompt,
    };
  }

  /// Creates a configuration from JSON data.
  factory ChatMemoryConfig.fromJson(Map<String, dynamic> json) {
    final presetName = json['preset'] as String;
    final preset = ChatMemoryPreset.values.firstWhere(
      (p) => p.name == presetName,
      orElse: () => ChatMemoryPreset.development,
    );

    return ChatMemoryConfig(
      preset: preset,
      maxTokens: json['maxTokens'] as int? ?? 4000,
      enableMemory: json['enableMemory'] as bool? ?? true,
      enableSummarization: json['enableSummarization'] as bool? ?? true,
      enableLogging: json['enableLogging'] as bool? ?? true,
      enablePersistence: json['enablePersistence'] as bool? ?? false,
      useSystemPrompt: json['useSystemPrompt'] as bool? ?? true,
      systemPrompt: json['systemPrompt'] as String?,
    );
  }

  @override
  String toString() {
    final promptPreview = systemPrompt != null
        ? (systemPrompt!.length > 50
              ? '${systemPrompt!.substring(0, 50)}...'
              : systemPrompt)
        : 'default';

    return 'ChatMemoryConfig('
        'preset: $preset, '
        'maxTokens: $maxTokens, '
        'enableMemory: $enableMemory, '
        'enableSummarization: $enableSummarization, '
        'enableLogging: $enableLogging, '
        'enablePersistence: $enablePersistence, '
        'useSystemPrompt: $useSystemPrompt, '
        'systemPrompt: $promptPreview'
        ')';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ChatMemoryConfig &&
        other.preset == preset &&
        other.maxTokens == maxTokens &&
        other.enableMemory == enableMemory &&
        other.enableSummarization == enableSummarization &&
        other.enableLogging == enableLogging &&
        other.enablePersistence == enablePersistence &&
        other.useSystemPrompt == useSystemPrompt &&
        other.systemPrompt == systemPrompt;
  }

  @override
  int get hashCode {
    return Object.hash(
      preset,
      maxTokens,
      enableMemory,
      enableSummarization,
      enableLogging,
      enablePersistence,
      useSystemPrompt,
      systemPrompt,
    );
  }
}

/// chat_memory
///
/// Public-facing aggregation of the most commonly used types and helpers in
/// the chat_memory package. Consumers can import this file as a single
/// entrypoint to access models, strategies, vector stores, and managers.
///
/// Example
/// ```dart
/// import 'package:chat_memory/chat_memory.dart';
///
/// // Simple usage with the new facade API
/// final chatMemory = await ChatMemory.development();
/// await chatMemory.addMessage('Hello!', role: 'user');
/// final context = await chatMemory.getContext();
/// print(context.promptText);
///
/// // Advanced usage with the original API
/// final manager = await EnhancedConversationManager.create();
/// await manager.appendUserMessage('Hello');
/// final prompt = await manager.buildPrompt(clientTokenBudget: 4000);
/// print(prompt.promptText);
/// ```
library;

// -------------------------
// Simplified ChatMemory API
// -------------------------
export 'chat_memory_facade.dart';
export 'chat_memory_builder.dart';
export 'chat_context.dart';
export 'chat_memory_config.dart';

// -------------------------
// Core models and payloads
// -------------------------
export 'core/models/message.dart';
export 'core/models/prompt_payload.dart';

// -------------------------
// Core utilities
// -------------------------
export 'core/utils/token_counter.dart';
export 'core/utils/message_operations.dart';
export 'core/utils/token_calculations.dart';

// -------------------------
// Conversation management
// -------------------------
export 'conversation/conversation_manager.dart';
export 'conversation/enhanced_conversation_manager.dart';
export 'conversation/callbacks/callback_manager.dart';
export 'conversation/analytics/conversation_analytics.dart';

// -------------------------
// Memory orchestration
// -------------------------
export 'memory/memory_manager.dart';
export 'memory/hybrid_memory_factory.dart';
export 'memory/session_store.dart';
export 'memory/memory_summarizer.dart';
export 'memory/semantic_retriever.dart';
export 'memory/memory_cleaner.dart';

// -------------------------
// Memory strategies & summarizers
// -------------------------
export 'memory/strategies/context_strategy.dart';
export 'memory/strategies/sliding_window_strategy.dart';
export 'memory/strategies/summarization_strategy.dart';
export 'memory/summarizers/summarizer.dart';
export 'memory/summarizers/deterministic_summarizer.dart';
export 'memory/summarizers/summarization_config.dart';

// -------------------------
// Core persistence
// -------------------------
export 'core/persistence/persistence_strategy.dart';
export 'core/persistence/in_memory_store.dart';

// -------------------------
// Memory semantic components
// -------------------------
export 'memory/embeddings/embedding_service.dart' hide EmbeddingConfig;
export 'memory/embeddings/simple_embedding_service.dart';
export 'memory/vector_stores/vector_store.dart';
export 'memory/vector_stores/local_vector_store.dart';
export 'memory/vector_stores/in_memory_vector_store.dart';

// -------------------------
// Data processing pipeline
// -------------------------
export 'processing/message_chunker.dart';
export 'processing/embedding_pipeline.dart';
export 'processing/message_processor.dart';
export 'processing/processing_config.dart';

// -------------------------
// Memory management workflows
// -------------------------
export 'workflows/memory_optimizer.dart' hide OptimizationResult;
export 'workflows/session_manager.dart';
export 'workflows/retention_policy.dart';
export 'workflows/workflow_scheduler.dart';
export 'workflows/memory_monitor.dart';

// -------------------------
// Conversation utilities
// -------------------------
export 'conversation/follow_up/follow_up_generator.dart';

// -------------------------
// Core error handling & logging
// -------------------------
export 'core/errors.dart';
export 'core/logging/chat_memory_logger.dart';

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
/// final manager = await EnhancedConversationManager.create();
/// await manager.appendUserMessage('Hello');
/// final prompt = await manager.buildPrompt(clientTokenBudget: 4000);
/// print(prompt.promptText);
/// ```
library;

// -------------------------
// Core models and payloads
// -------------------------
export 'models/message.dart';
export 'models/prompt_payload.dart';

// -------------------------
// Token utilities
// -------------------------
export 'utils/token_counter.dart';
export 'utils/message_operations.dart';
export 'utils/token_calculations.dart';

// -------------------------
// Conversation management
// -------------------------
export 'conversation_manager.dart';
export 'enhanced_conversation_manager.dart';
export 'callbacks/callback_manager.dart';
export 'analytics/conversation_analytics.dart';

// -------------------------
// Memory orchestration
// -------------------------
export 'memory/memory_manager.dart';
export 'memory/hybrid_memory_factory.dart';
export 'memory/session_store.dart';
export 'memory/memory_summarizer.dart';
export 'memory/semantic_retriever.dart';

// -------------------------
// Strategies & Summarizers
// -------------------------
export 'strategies/context_strategy.dart';
export 'strategies/sliding_window_strategy.dart';
export 'strategies/summarization_strategy.dart';
export 'summarizers/summarizer.dart';
export 'summarizers/deterministic_summarizer.dart';
export 'summarizers/summarization_config.dart';

// -------------------------
// Persistence
// -------------------------
export 'persistence/persistence_strategy.dart';
export 'persistence/in_memory_store.dart';

// -------------------------
// Semantic components
// -------------------------
export 'embeddings/embedding_service.dart' hide EmbeddingConfig;
export 'embeddings/simple_embedding_service.dart';
export 'vector_stores/vector_store.dart';
export 'vector_stores/local_vector_store.dart';
export 'vector_stores/in_memory_vector_store.dart';

// -------------------------
// Advanced Processing Pipeline
// -------------------------
export 'processing/message_chunker.dart';
export 'processing/embedding_pipeline.dart';
export 'processing/message_processor.dart';
export 'processing/processing_config.dart';

// -------------------------
// Misc utilities
// -------------------------
export 'follow_up/follow_up_generator.dart';

// -------------------------
// Error handling & Logging
// -------------------------
export 'errors.dart';
export 'logging/chat_memory_logger.dart';

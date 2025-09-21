/// Chat Memory - Intelligent conversation memory for LLM applications
///
/// A powerful Flutter package that provides intelligent conversation memory
/// management with semantic search, automatic summarization, and token optimization.
///
/// ## Quick Start
///
/// ### Simple Usage (Recommended)
///
/// ```dart
/// import 'package:chat_memory/chat_memory.dart';
///
/// // Create a ChatMemory instance with preset configuration
/// final chatMemory = await ChatMemory.development();
///
/// // Add messages to the conversation
/// await chatMemory.addMessage('Hello!', role: 'user');
/// await chatMemory.addMessage('Hi there! How can I help?', role: 'assistant');
/// await chatMemory.addMessage('What\'s the weather like?', role: 'user');
///
/// // Get context for LLM prompts with semantic retrieval
/// final context = await chatMemory.getContext(query: 'weather information');
/// print('Prompt: ${context.promptText}');
/// print('Token count: ${context.estimatedTokens}');
/// print('Relevant messages: ${context.messageCount}');
/// ```
///
/// ### Custom Configuration
///
/// ```dart
/// // Use builder pattern for custom setups
/// final chatMemory = await ChatMemoryBuilder()
///     .production()
///     .withMaxTokens(4000)
///     .withSemanticMemory(enabled: true)
///     .withSummarization(enabled: true)
///     .withPersistence(enabled: true, databasePath: './chat_memory.db')
///     .build();
/// ```
///
/// ### Preset Configurations
///
/// - **Development**: Fast setup with in-memory storage and enhanced logging
/// - **Production**: Optimized for performance with persistent storage
/// - **Minimal**: Basic functionality with minimal resource usage
///
/// ### Advanced Usage
///
/// For fine-grained control, you can use the underlying components directly:
///
/// ```dart
/// // Direct access to enhanced conversation manager
/// final manager = await EnhancedConversationManager.create(
///   preset: MemoryPreset.production,
///   maxTokens: 8000,
/// );
///
/// await manager.appendUserMessage('Hello');
/// final prompt = await manager.buildPrompt(clientTokenBudget: 4000);
/// ```
///
/// ## Features
///
/// - **Semantic Memory**: Retrieve relevant past messages based on meaning
/// - **Auto Summarization**: Automatically condense old conversations
/// - **Token Optimization**: Stay within LLM token limits intelligently
/// - **Multiple Storage Options**: In-memory, local persistence, or custom
/// - **Analytics & Callbacks**: Monitor and react to memory operations
/// - **Type Safety**: Full Dart type safety with comprehensive error handling
///
library;

export 'src/chat_memory_base.dart';

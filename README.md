# Chat Memory - Hybrid Memory Management System

A powerful Dart package that provides sophisticated memory management for conversational AI applications. Features include **summarization-based compression**, **semantic retrieval**, and **hybrid memory layers** for optimal context management.

## ✨ Features

### 🧠 Hybrid Memory Architecture
- **Short-term Rolling Memory**: Recent messages preserved for immediate context
- **Long-term Summaries**: Automatic compression of older conversations
- **Semantic Memory**: Vector-based retrieval of relevant historical context
- **Token Budget Management**: Intelligent context fitting within LLM limits

### 🔄 Summarization Strategies  
- **Chunked Summarization**: Process messages in manageable chunks
- **Layered Summaries**: Create summaries of summaries to prevent information loss  
- **Configurable Retention**: Control how much recent context to preserve
- **Multiple Summarizer Backends**: Pluggable summarization services

### 🔍 Semantic Search
- **Local Vector Storage**: SQLite-based embedding storage for persistence
- **In-Memory Storage**: Fast retrieval for development and testing
- **Semantic Retrieval**: Find contextually relevant messages across conversation history
- **Hybrid Scoring**: Combine recency and semantic similarity for optimal results

### 🏗️ Flexible Architecture
- **Preset Configurations**: Quick setup for common use cases
- **Builder Pattern**: Fine-grained control over memory components
- **Pluggable Components**: Custom summarizers, embeddings, and storage backends
- **Production Ready**: Persistent storage with efficient indexing

## 🚀 Quick Start

### Basic Usage

```dart
import 'package:chat_memory/chat_memory.dart';

// Create an enhanced conversation manager
final manager = await EnhancedConversationManager.create(
  preset: MemoryPreset.production,
  maxTokens: 8000,
);

// Add messages to the conversation
await manager.appendSystemMessage('You are a helpful assistant.');
await manager.appendUserMessage('Tell me about machine learning');
await manager.appendAssistantMessage(
  'Machine learning is a subset of AI where algorithms learn patterns...'
);

// Get optimized context for your LLM
final prompt = await manager.buildPrompt(
  clientTokenBudget: 6000,
  userQuery: 'explain neural networks',
);

print('Optimized prompt: ${prompt.promptText}');
print('Tokens: ${prompt.estimatedTokens}');
print('Summary: ${prompt.summary}');
```

### Advanced Configuration

```dart
// Use builder pattern for custom setup
final customManager = MemoryManagerBuilder()
    .withMaxTokens(12000)
    .withLocalVectorStore(databasePath: 'my_vectors.db')
    .withSimpleEmbedding(dimensions: 512)
    .enableSemanticMemory(topK: 8, minSimilarity: 0.3)
    .build();

final conversationManager = EnhancedConversationManager(
  memoryManager: customManager,
  onSummaryCreated: (summary) => print('Summary: ${summary.content}'),
  onMessageStored: (message) => print('Stored: ${message.role}'),
);
```

## 🔧 Memory Presets

Choose from predefined configurations optimized for different use cases:

### Development
```dart
final manager = await EnhancedConversationManager.create(
  preset: MemoryPreset.development,
  maxTokens: 4000,
);
```
- **Fast setup** with in-memory storage
- **Simple embedding** service for testing
- **Balanced summarization** strategy
- **No persistent storage** required

### Production
```dart
final manager = await EnhancedConversationManager.create(
  preset: MemoryPreset.production,
  maxTokens: 8000,
  databasePath: 'chat_vectors.db',
);
```
- **Persistent SQLite** vector storage
- **Semantic search** enabled
- **Optimized for scale** and reliability
- **Comprehensive memory layers**

### Performance
```dart
final manager = await EnhancedConversationManager.create(
  preset: MemoryPreset.performance,
  maxTokens: 16000,
);
```
- **Aggressive summarization** for large conversations
- **Enhanced semantic retrieval** (8 top results)
- **Lower similarity threshold** for broader context
- **Optimized for high-volume** applications

### Minimal
```dart
final manager = await EnhancedConversationManager.create(
  preset: MemoryPreset.minimal,
  maxTokens: 2000,
);
```
- **Summarization only** (no semantic search)
- **Lightweight footprint**
- **Fast performance**
- **Minimal dependencies**

## 📊 Memory Flow Architecture

### 1. Pre-checks
```dart
// If conversation fits in token budget, return as-is
if (totalTokens <= maxTokens) return messages;
```

### 2. Summarization Layer (Compression Memory)
```dart
// Apply summarization strategy to exceed content
final strategyResult = await contextStrategy.apply(
  messages: messages,
  tokenBudget: maxTokens,
  tokenCounter: tokenCounter,
);
```

### 3. Embedding Layer (Semantic Memory) 
```dart
// Retrieve semantically relevant historical context
final semanticMessages = await vectorStore.search(
  queryEmbedding: await embeddingService.embed(userQuery),
  topK: config.semanticTopK,
  minSimilarity: config.minSimilarity,
);
```

### 4. Final Prompt Construction
```dart
final finalPrompt = [
  if (systemMessage != null) systemMessage,
  ...longTermSummaries,    // Summarized history
  ...retrievedFactMessages, // Semantic retrieval  
  ...recentMessages,       // Rolling window
];
```

## 🧩 Core Components

### MemoryManager
Central orchestrator that coordinates all memory layers:

```dart
final memoryManager = MemoryManager(
  contextStrategy: SummarizationStrategy(...),
  tokenCounter: HeuristicTokenCounter(),
  config: MemoryConfig(
    maxTokens: 8000,
    semanticTopK: 5,
    enableSemanticMemory: true,
  ),
  vectorStore: LocalVectorStore(),
  embeddingService: SimpleEmbeddingService(),
);
```

### Vector Stores
Choose your storage backend:

```dart
// Local SQLite storage (persistent)
final vectorStore = LocalVectorStore(
  databasePath: 'embeddings.db',
);

// In-memory storage (fast, temporary)
final vectorStore = InMemoryVectorStore();
```

### Embedding Services  
Convert text to vectors for semantic search:

```dart
// Simple deterministic embeddings (for testing)
final embeddingService = SimpleEmbeddingService(dimensions: 384);

// Custom embedding service (implement EmbeddingService interface)
final embeddingService = MyCustomEmbeddingService();
```

### Summarization Strategies
Control how conversations are compressed:

```dart
// Balanced approach (recommended)
final strategy = SummarizationStrategyFactory.balanced(
  maxTokens: 8000,
  summarizer: DeterministicSummarizer(),
  tokenCounter: HeuristicTokenCounter(),
);

// Aggressive compression
final strategy = SummarizationStrategyFactory.aggressive(...);

// Conservative (keeps more recent messages)
final strategy = SummarizationStrategyFactory.conservative(...);
```

## 📈 Monitoring & Statistics

Get insights into your conversation memory:

```dart
final stats = await manager.getStats();
print('Total messages: ${stats.totalMessages}');
print('Total tokens: ${stats.totalTokens}');
print('Vector embeddings: ${stats.vectorCount}');
print('Conversation duration: ${stats.conversationDuration?.inMinutes} minutes');

// Enhanced prompt with metadata
final enhancedPrompt = await manager.buildEnhancedPrompt(
  clientTokenBudget: 8000,
  userQuery: 'current topic',
);

print('Processing time: ${enhancedPrompt.metadata['processingTimeMs']}ms');
print('Semantic messages: ${enhancedPrompt.semanticMessages.length}');
print('Strategy used: ${enhancedPrompt.metadata['strategyUsed']}');
```

## 🔌 Extensibility

### Custom Summarizer
```dart
class CustomSummarizer implements Summarizer {
  @override
  Future<SummaryInfo> summarize(
    List<Message> messages,
    TokenCounter tokenCounter,
  ) async {
    // Your custom summarization logic
    return SummaryInfo(
      chunkId: 'custom_${DateTime.now().millisecondsSinceEpoch}',
      summary: 'Your summary here...',
      tokenEstimateBefore: tokenCounter.estimateTokens(content),
      tokenEstimateAfter: tokenCounter.estimateTokens(summary),
    );
  }
}
```

### Custom Embedding Service
```dart
class CustomEmbeddingService implements EmbeddingService {
  @override
  Future<List<double>> embed(String text) async {
    // Your embedding logic (e.g., OpenAI, Google AI, local model)
    return embeddings;
  }
  
  @override
  int get dimensions => 1536; // Your embedding dimensions
  
  @override
  String get name => 'CustomEmbeddings';
}
```

### Custom Vector Store
```dart  
class CustomVectorStore implements VectorStore {
  @override
  Future<void> store(VectorEntry entry) async {
    // Store in your preferred database (Pinecone, Qdrant, etc.)
  }
  
  @override
  Future<List<SimilaritySearchResult>> search({
    required List<double> queryEmbedding,
    required int topK,
    double minSimilarity = 0.0,
  }) async {
    // Your search implementation
    return results;
  }
}
```

## 🛠️ Installation

Add to your `pubspec.yaml`:

```yaml
dependencies:
  chat_memory: ^1.0.0
  
  # For local vector storage
  sqflite: ^2.3.0
  sqflite_common_ffi: ^2.3.0  # For desktop platforms
```

## 📋 Requirements

- **Dart SDK**: ^3.9.2
- **Flutter**: Compatible with Flutter applications
- **Desktop Support**: Windows, macOS, Linux via SQLite FFI
- **Mobile Support**: iOS, Android via native SQLite

## 🎯 Use Cases

### Chatbots & Virtual Assistants
- Maintain context across long conversations
- Retrieve relevant information from conversation history
- Automatically summarize previous interactions

### Customer Support
- Access historical customer interactions
- Find similar resolved issues through semantic search
- Maintain conversation continuity across sessions  

### Educational Applications  
- Track learning progress and topics covered
- Retrieve related concepts from previous lessons
- Summarize learning sessions

### Content Creation
- Maintain narrative consistency in long-form content
- Reference previous creative decisions
- Find thematically related content

## 📚 Examples

Check out the [`example/`](example/) directory for comprehensive usage examples:

- **Basic Usage**: Simple setup and conversation management
- **Preset Configurations**: Different memory configurations for various use cases
- **Advanced Builder**: Fine-grained control using the builder pattern
- **Semantic Retrieval**: Demonstrating semantic search capabilities
- **Statistics & Monitoring**: Conversation analytics and performance metrics

## 🤝 Contributing

Contributions are welcome! Please see [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- Inspired by research in conversation memory systems
- Built with modern Dart patterns and best practices
- Designed for production scalability and reliability

---

**Built with ❤️ for the Dart & Flutter community**
# Advanced Processing Pipeline

The chat_memory package includes a sophisticated data processing workflow pipeline designed for enterprise-grade message processing with intelligent chunking, resilient embedding generation, and flexible configuration.

## 📋 Table of Contents

- [Overview](#overview)
- [Core Components](#core-components)
- [Quick Start](#quick-start)
- [Configuration](#configuration)
- [Examples](#examples)
- [Performance & Monitoring](#performance--monitoring)
- [Best Practices](#best-practices)
- [API Reference](#api-reference)

## Overview

The processing pipeline provides a comprehensive solution for handling large-scale text processing with these key capabilities:

🧩 **Intelligent Chunking** - Multiple strategies for optimal message segmentation  
⚡ **Resilient Processing** - Circuit breakers, retry logic, and fault tolerance  
🎛️ **Configurable Stages** - Flexible pipeline orchestration  
📊 **Monitoring & Metrics** - Comprehensive performance tracking  
🔧 **Preset Configurations** - Ready-to-use configurations for different scenarios

## Core Components

### MessageChunker

Intelligently segments messages into smaller, manageable pieces while preserving semantic coherence.

**Supported Strategies:**

- `fixedToken` - Consistent token-based chunking
- `fixedChar` - Character-based chunking
- `wordBoundary` - Word-aware segmentation
- `sentenceBoundary` - Sentence-aware chunking
- `paragraphBoundary` - Paragraph-aware segmentation
- `slidingWindow` - Overlapping chunks for context preservation
- `delimiter` - Custom delimiter-based chunking
- `semantic` - Future semantic-aware chunking

### EmbeddingPipeline

Advanced batch processing with enterprise-grade resilience patterns:

**Key Features:**

- **Circuit Breaker Pattern** - Prevents cascade failures
- **Exponential Backoff** - Intelligent retry strategies
- **Adaptive Batch Sizing** - Performance-based optimization
- **Rate Limiting** - Prevents service overload
- **Caching System** - Reduces redundant processing
- **Quality Validation** - Embedding quality scoring

### MessageProcessor

Main pipeline orchestrator that coordinates all processing stages:

**Processing Stages:**

1. **Validation** - Input validation and filtering
2. **Chunking** - Message segmentation
3. **Embedding** - Vector generation
4. **Storage** - Persistence layer
5. **Post-Processing** - Custom transformations

### ProcessingConfig

Comprehensive configuration system with preset options:

**Available Presets:**

- `development` - Fast development setup
- `production` - Full pipeline with persistence
- `highThroughput` - Optimized for large datasets
- `lowLatency` - Real-time processing
- `memoryOptimized` - Resource-constrained environments

## Quick Start

### Basic Usage

```dart
import 'package:chat_memory/chat_memory.dart';

// Create components
final tokenCounter = HeuristicTokenCounter(charsPerToken: 4);
final chunker = MessageChunker(tokenCounter: tokenCounter);
final embeddingService = SimpleEmbeddingService(dimensions: 128);
final embeddingPipeline = EmbeddingPipeline(embeddingService: embeddingService);

// Build processor
final processor = MessageProcessorFactory.createDevelopment(
  chunker: chunker,
  embeddingPipeline: embeddingPipeline,
);

// Process messages
final messages = [
  Message(
    id: 'msg_1',
    role: MessageRole.user,
    content: 'Your message content here...',
    timestamp: DateTime.now(),
  ),
];

final result = await processor.processMessages(
  messages,
  ProcessingConfig(),
);

print('Processed ${result.processedMessages.length} messages');
print('Created ${result.chunks.length} chunks');
print('Generated ${result.embeddingResult?.embeddings.length ?? 0} embeddings');
```

### Using Preset Configurations

```dart
// Development preset - fast and simple
final devConfig = ProcessingPipelineConfig.fromPreset(ProcessingPreset.development);

// Production preset - full features
final prodConfig = ProcessingPipelineConfig.fromPreset(ProcessingPreset.production);

// High-throughput preset - optimized for scale
final htConfig = ProcessingPipelineConfig.fromPreset(ProcessingPreset.highThroughput);

// Process with preset configuration
final processor = MessageProcessorFactory.createProduction(
  chunker: chunker,
  embeddingPipeline: embeddingPipeline,
  vectorStore: InMemoryVectorStore(),
  sessionStore: SessionStore(config: MemoryConfig()),
);

final result = await processor.processMessages(
  messages,
  prodConfig.processingConfig,
);
```

## Configuration

### Chunking Configuration

```dart
const chunkingConfig = ChunkingConfig(
  maxChunkTokens: 500,              // Maximum tokens per chunk
  maxChunkChars: 2000,              // Maximum characters per chunk
  strategy: ChunkingStrategy.sentenceBoundary,  // Chunking strategy
  preserveWords: true,              // Preserve word boundaries
  preserveSentences: true,          // Preserve sentence boundaries
  overlapRatio: 0.1,               // Overlap for sliding window
  customDelimiters: ['\\n\\n'],      // Custom delimiters
);
```

### Embedding Configuration

```dart
const embeddingConfig = EmbeddingConfig(
  processingMode: ProcessingMode.parallel,  // Processing mode
  maxBatchSize: 50,                        // Maximum batch size
  minBatchSize: 1,                         // Minimum batch size
  maxRequestsPerSecond: 10.0,              // Rate limiting
  circuitBreaker: CircuitBreakerConfig(    // Circuit breaker settings
    maxFailures: 5,
    timeout: Duration(minutes: 1),
    enabled: true,
  ),
  retryConfig: RetryConfig(                // Retry configuration
    maxRetries: 3,
    strategy: RetryStrategy.exponential,
    baseDelay: Duration(milliseconds: 100),
  ),
  enableCaching: true,                     // Enable caching
  cacheMaxSize: 1000,                      // Cache size limit
  enableValidation: true,                  // Enable validation
  qualityThreshold: 0.5,                   // Quality threshold
);
```

### Processing Configuration

```dart
const processingConfig = ProcessingConfig(
  stages: [                               // Processing stages
    ProcessingStage.validation,
    ProcessingStage.chunking,
    ProcessingStage.embedding,
    ProcessingStage.storage,
  ],
  mode: ProcessingMode.parallel,          // Processing mode
  continueOnError: false,                 // Error handling
  maxConcurrency: 10,                     // Concurrency limit
);
```

## Examples

### Advanced Chunking

```dart
// Demonstrate different chunking strategies
final strategies = [
  ('Fixed Token', ChunkingConfig(
    strategy: ChunkingStrategy.fixedToken,
    maxChunkTokens: 100,
  )),
  ('Sentence Boundary', ChunkingConfig(
    strategy: ChunkingStrategy.sentenceBoundary,
    maxChunkTokens: 150,
    preserveSentences: true,
  )),
  ('Sliding Window', ChunkingConfig(
    strategy: ChunkingStrategy.slidingWindow,
    maxChunkChars: 500,
    overlapRatio: 0.2,
  )),
];

for (final (name, config) in strategies) {
  final chunks = await chunker.chunkMessage(message, config);
  print('$name: ${chunks.length} chunks');
}
```

### Circuit Breaker Pattern

```dart
// Configure circuit breaker for resilience
const embeddingConfig = EmbeddingConfig(
  circuitBreaker: CircuitBreakerConfig(
    maxFailures: 3,                      // Open after 3 failures
    timeout: Duration(seconds: 30),      // Wait 30s before retry
    maxHalfOpenAttempts: 2,             // Allow 2 test attempts
    enabled: true,
  ),
);

final pipeline = EmbeddingPipeline(embeddingService: embeddingService);

// Check circuit breaker status
final status = pipeline.getCircuitBreakerStatus();
print('Circuit breaker state: ${status['state']}');
```

### Adaptive Processing

```dart
// Adaptive processing adjusts batch size based on performance
const adaptiveConfig = EmbeddingConfig(
  processingMode: ProcessingMode.adaptive,
  minBatchSize: 1,
  maxBatchSize: 20,
);

final result = await pipeline.processChunks(chunks, adaptiveConfig);
print('Adaptive processing completed with ${result.embeddings.length} embeddings');
```

### Performance Monitoring

```dart
// Track chunking statistics
final chunkStats = chunker.getStatistics();
print('Chunking Statistics:');
print('  Total messages: ${chunkStats.totalMessages}');
print('  Total chunks: ${chunkStats.totalChunks}');
print('  Avg chunks/message: ${chunkStats.averageChunksPerMessage}');
print('  Avg chunk size: ${chunkStats.averageChunkSize}');

// Track pipeline statistics
final pipelineStats = pipeline.getStatistics();
print('Pipeline Statistics:');
print('  Total items: ${pipelineStats.totalItems}');
print('  Success rate: ${pipelineStats.successfulItems / pipelineStats.totalItems}');
print('  Cache hit rate: ${pipelineStats.cacheHitRate}');
print('  Avg time/item: ${pipelineStats.averageTimePerItem}ms');
```

## Performance & Monitoring

### Health Checks

```dart
// Check component health status
final processor = MessageProcessorFactory.createFull(/* components */);
final health = processor.getHealthStatus();

health.forEach((component, status) {
  print('$component: $status');
});
// Output:
// chunker: available
// embeddingPipeline: available
// vectorStore: available
// sessionStore: available
```

### Component Statistics

```dart
// Get detailed component statistics
final componentStats = processor.getComponentStatistics();
print('Component Statistics: $componentStats');
```

### Configuration Validation

```dart
// Validate configuration before use
try {
  const config = ProcessingPipelineConfig(
    chunkingConfig: ChunkingConfig(maxChunkTokens: 1000),
    embeddingConfig: EmbeddingConfig(maxBatchSize: 50),
  );

  config.validate();  // Throws exception if invalid
  print('Configuration is valid');
} catch (e) {
  print('Configuration error: $e');
}
```

## Best Practices

### 1. Choose Appropriate Presets

```dart
// Development: Fast iteration, minimal features
final devConfig = ProcessingPipelineConfig.fromPreset(ProcessingPreset.development);

// Production: Full features, persistence, monitoring
final prodConfig = ProcessingPipelineConfig.fromPreset(ProcessingPreset.production);

// High-throughput: Optimized for large datasets
final htConfig = ProcessingPipelineConfig.fromPreset(ProcessingPreset.highThroughput);
```

### 2. Configure Circuit Breakers

```dart
// Configure circuit breakers for external services
const embeddingConfig = EmbeddingConfig(
  circuitBreaker: CircuitBreakerConfig(
    maxFailures: 5,
    timeout: Duration(minutes: 2),
    enabled: true,
  ),
);
```

### 3. Monitor Performance

```dart
// Regular monitoring of pipeline performance
void monitorPerformance(MessageProcessor processor) {
  final health = processor.getHealthStatus();
  final stats = processor.getComponentStatistics();

  // Log health status
  if (health.values.any((status) => status != 'available')) {
    logger.warning('Component health issues detected: $health');
  }

  // Monitor success rates
  final chunkStats = stats['chunking'] as ChunkingStats?;
  if (chunkStats != null && chunkStats.averageChunksPerMessage > 10) {
    logger.info('High chunking rate detected, consider larger chunk sizes');
  }
}
```

### 4. Error Handling

```dart
// Proper error handling for pipeline operations
try {
  final result = await processor.processMessages(messages, config);

  if (!result.isSuccess) {
    logger.warning('Processing completed with errors: ${result.errors.length}');
    for (final error in result.errors) {
      logger.error('Stage ${error.stage}: ${error.message}');
    }
  }
} catch (e, stackTrace) {
  logger.error('Pipeline processing failed', e, stackTrace);
  // Implement fallback strategy
}
```

### 5. Resource Management

```dart
// Configure resource limits appropriately
const performanceConfig = PerformanceConfig(
  memoryLimit: 1000000000,  // 1GB limit
  enableGarbageCollection: true,
  threadPoolSize: 4,
);

const config = ProcessingPipelineConfig(
  performanceConfig: performanceConfig,
);
```

## API Reference

### MessageChunker

```dart
class MessageChunker {
  MessageChunker({required TokenCounter tokenCounter});

  Future<List<MessageChunk>> chunkMessage(Message message, ChunkingConfig config);
  Future<List<MessageChunk>> chunkMessages(List<Message> messages, ChunkingConfig config);
  ChunkingStats getStatistics();
  void resetStatistics();
}
```

### EmbeddingPipeline

```dart
class EmbeddingPipeline {
  EmbeddingPipeline({required EmbeddingService embeddingService});

  Future<EmbeddingResult> processChunks(List<MessageChunk> chunks, EmbeddingConfig config);
  Future<EmbeddingResult> processMessages(List<String> messages, EmbeddingConfig config);
  Map<String, dynamic> getCircuitBreakerStatus();
  EmbeddingStats getStatistics();
  void resetStatistics();
}
```

### MessageProcessor

```dart
class MessageProcessor {
  Future<ProcessingResult> processMessages(List<Message> messages, ProcessingConfig config);
  Future<ProcessingResult> processSingleMessage(Message message, ProcessingConfig config);
  Map<String, dynamic> getHealthStatus();
  Map<String, dynamic> getComponentStatistics();
}
```

### Factory Classes

```dart
class MessageProcessorFactory {
  static MessageProcessor createBasic({required MessageChunker chunker});
  static MessageProcessor createDevelopment({required MessageChunker chunker, required EmbeddingPipeline embeddingPipeline});
  static MessageProcessor createProduction({required MessageChunker chunker, required EmbeddingPipeline embeddingPipeline, required VectorStore vectorStore, required SessionStore sessionStore});
  static MessageProcessor createFull({required MessageChunker chunker, required EmbeddingPipeline embeddingPipeline, required VectorStore vectorStore, required SessionStore sessionStore});
}
```

### Configuration Classes

```dart
class ProcessingPipelineConfig {
  const ProcessingPipelineConfig({...});
  factory ProcessingPipelineConfig.fromPreset(ProcessingPreset preset);
  ProcessingPipelineConfig copyWith({...});
  void validate();
  Map<String, dynamic> toJson();
  factory ProcessingPipelineConfig.fromJson(Map<String, dynamic> json);
}
```

---

For more examples and detailed API documentation, see the [example applications](example/) and [API documentation](https://pub.dev/documentation/chat_memory/).

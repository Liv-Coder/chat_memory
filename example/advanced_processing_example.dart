import 'dart:developer' as developer;
import 'package:chat_memory/chat_memory.dart';

/// Advanced processing pipeline example showcasing the sophisticated
/// data processing workflow capabilities of the chat_memory package.
///
/// This example demonstrates:
/// - Intelligent message chunking with multiple strategies
/// - Advanced embedding pipeline with circuit breakers and retry logic
/// - Configurable processing stages and error handling
/// - Performance monitoring and statistics
/// - Different preset configurations for various use cases

Future<void> main() async {
  developer.log('🚀 Advanced Processing Pipeline Example');
  developer.log('=' * 50);

  await messageChunkingExample();
  await embeddingPipelineExample();
  await fullProcessingPipelineExample();
  await presetConfigurationsExample();
  await performanceMonitoringExample();
}

/// Example 1: Intelligent Message Chunking
Future<void> messageChunkingExample() async {
  developer.log('\n📄 Example 1: Intelligent Message Chunking');
  developer.log('-' * 40);

  // Create a chunker with a simple token counter
  final tokenCounter = HeuristicTokenCounter(charsPerToken: 4);
  final chunker = MessageChunker(tokenCounter: tokenCounter);

  // Create a long message to demonstrate chunking
  final longMessage = Message(
    id: 'long_msg_1',
    role: MessageRole.user,
    content: '''
    This is a very long message that demonstrates the intelligent chunking capabilities 
    of the chat_memory processing pipeline. The system can break down large content 
    into smaller, manageable pieces while preserving semantic coherence and context.
    
    Different chunking strategies are available:
    - Fixed token chunking for consistent sizes
    - Word boundary preservation for readability
    - Sentence boundary chunking for semantic coherence
    - Sliding window with overlap for context preservation
    - Custom delimiter-based chunking for structured content
    
    The chunker also provides detailed statistics and performance metrics
    to help optimize your processing workflow.
    ''',
    timestamp: DateTime.now(),
  );

  // Demonstrate different chunking strategies
  final strategies = [
    (
      'Fixed Token',
      ChunkingConfig(
        strategy: ChunkingStrategy.fixedToken,
        maxChunkTokens: 50,
        preserveWords: true,
      ),
    ),
    (
      'Sentence Boundary',
      ChunkingConfig(
        strategy: ChunkingStrategy.sentenceBoundary,
        maxChunkTokens: 60,
        preserveSentences: true,
      ),
    ),
    (
      'Sliding Window',
      ChunkingConfig(
        strategy: ChunkingStrategy.slidingWindow,
        maxChunkChars: 200,
        overlapRatio: 0.2,
      ),
    ),
  ];

  for (final (name, config) in strategies) {
    developer.log('\n📝 $name Strategy:');
    final chunks = await chunker.chunkMessage(longMessage, config);

    developer.log('  Created ${chunks.length} chunks');
    for (int i = 0; i < chunks.length && i < 2; i++) {
      final chunk = chunks[i];
      developer.log('  Chunk ${i + 1}: "${chunk.content.substring(0, 50)}..."');
      developer.log(
        '    Tokens: ${chunk.estimatedTokens}, Chars: ${chunk.content.length}',
      );
    }
  }

  // Show chunking statistics
  final stats = chunker.getStatistics();
  developer.log('\n📊 Chunking Statistics:');
  developer.log('  Total messages processed: ${stats.totalMessages}');
  developer.log('  Total chunks created: ${stats.totalChunks}');
  developer.log(
    '  Average chunks per message: ${stats.averageChunksPerMessage.toStringAsFixed(2)}',
  );
  developer.log(
    '  Average chunk size: ${stats.averageChunkSize.toStringAsFixed(0)} chars',
  );
}

/// Example 2: Advanced Embedding Pipeline
Future<void> embeddingPipelineExample() async {
  developer.log('\n⚡ Example 2: Advanced Embedding Pipeline');
  developer.log('-' * 40);

  // Create embedding service and pipeline
  final embeddingService = SimpleEmbeddingService(dimensions: 128);
  final pipeline = EmbeddingPipeline(embeddingService: embeddingService);

  // Create sample message chunks
  final chunks = [
    MessageChunk(
      id: 'chunk_1',
      content: 'This is the first chunk about machine learning concepts.',
      parentMessageId: 'msg_1',
      chunkIndex: 0,
      totalChunks: 3,
      startPosition: 0,
      endPosition: 55,
      estimatedTokens: 12,
    ),
    MessageChunk(
      id: 'chunk_2',
      content:
          'Deep learning is a subset of machine learning with neural networks.',
      parentMessageId: 'msg_1',
      chunkIndex: 1,
      totalChunks: 3,
      startPosition: 55,
      endPosition: 122,
      estimatedTokens: 13,
    ),
    MessageChunk(
      id: 'chunk_3',
      content:
          'Natural language processing enables computers to understand text.',
      parentMessageId: 'msg_1',
      chunkIndex: 2,
      totalChunks: 3,
      startPosition: 122,
      endPosition: 187,
      estimatedTokens: 11,
    ),
  ];

  // Demonstrate different processing modes
  final configs = [
    (
      'Sequential',
      EmbeddingConfig(
        processingMode: ProcessingMode.sequential,
        maxBatchSize: 1,
        enableValidation: true,
      ),
    ),
    (
      'Parallel',
      EmbeddingConfig(
        processingMode: ProcessingMode.parallel,
        maxBatchSize: 10,
        enableCaching: true,
        retryConfig: RetryConfig(maxRetries: 2),
      ),
    ),
    (
      'Adaptive',
      EmbeddingConfig(
        processingMode: ProcessingMode.adaptive,
        minBatchSize: 1,
        maxBatchSize: 5,
        enableValidation: true,
        qualityThreshold: 0.7,
      ),
    ),
  ];

  for (final (name, config) in configs) {
    developer.log('\n🔄 $name Processing:');

    final stopwatch = Stopwatch()..start();
    final result = await pipeline.processChunks(chunks, config);
    stopwatch.stop();

    developer.log('  Processed ${result.embeddings.length} embeddings');
    developer.log('  Failures: ${result.failures.length}');
    developer.log(
      '  Success rate: ${(result.successRate * 100).toStringAsFixed(1)}%',
    );
    developer.log('  Processing time: ${stopwatch.elapsedMilliseconds}ms');

    if (result.embeddings.isNotEmpty) {
      final firstEmbedding = result.embeddings.first;
      developer.log(
        '  Sample embedding: [${firstEmbedding.embedding.take(5).join(', ')}...]',
      );
      developer.log(
        '  Quality score: ${firstEmbedding.qualityScore.toStringAsFixed(3)}',
      );
    }
  }

  // Show circuit breaker status
  final circuitStatus = pipeline.getCircuitBreakerStatus();
  developer.log('\n🔒 Circuit Breaker Status: ${circuitStatus['state']}');

  // Show processing statistics
  final pipelineStats = pipeline.getStatistics();
  developer.log('\n📈 Pipeline Statistics:');
  developer.log('  Total items processed: ${pipelineStats.totalItems}');
  developer.log('  Successful items: ${pipelineStats.successfulItems}');
  developer.log(
    '  Cache hit rate: ${(pipelineStats.cacheHitRate * 100).toStringAsFixed(1)}%',
  );
  developer.log(
    '  Average time per item: ${pipelineStats.averageTimePerItem.toStringAsFixed(2)}ms',
  );
}

/// Example 3: Full Processing Pipeline
Future<void> fullProcessingPipelineExample() async {
  developer.log('\n🏭 Example 3: Full Processing Pipeline');
  developer.log('-' * 40);

  // Create components
  final tokenCounter = HeuristicTokenCounter(charsPerToken: 4);
  final chunker = MessageChunker(tokenCounter: tokenCounter);
  final embeddingService = SimpleEmbeddingService(dimensions: 64);
  final embeddingPipeline = EmbeddingPipeline(
    embeddingService: embeddingService,
  );

  // Build processor with all components
  final processor = MessageProcessorFactory.createFull(
    chunker: chunker,
    embeddingPipeline: embeddingPipeline,
    vectorStore: InMemoryVectorStore(),
    sessionStore: SessionStore(config: MemoryConfig()),
  );

  // Create test messages
  final messages = [
    Message(
      id: 'msg_1',
      role: MessageRole.user,
      content:
          'What are the main benefits of using artificial intelligence in healthcare?',
      timestamp: DateTime.now(),
    ),
    Message(
      id: 'msg_2',
      role: MessageRole.assistant,
      content:
          'AI in healthcare offers several key benefits: improved diagnostic accuracy, personalized treatment plans, drug discovery acceleration, and operational efficiency gains.',
      timestamp: DateTime.now(),
    ),
    Message(
      id: 'msg_3',
      role: MessageRole.user,
      content:
          'Can you explain how machine learning algorithms help in medical diagnosis?',
      timestamp: DateTime.now(),
    ),
  ];

  // Configure processing pipeline
  final config = ProcessingConfig(
    stages: [
      ProcessingStage.validation,
      ProcessingStage.chunking,
      ProcessingStage.embedding,
      ProcessingStage.storage,
      ProcessingStage.postProcessing,
    ],
    chunkingConfig: ChunkingConfig(
      maxChunkTokens: 100,
      strategy: ChunkingStrategy.sentenceBoundary,
      preserveWords: true,
    ),
    embeddingConfig: EmbeddingConfig(
      processingMode: ProcessingMode.parallel,
      maxBatchSize: 5,
      enableValidation: true,
      normalize: true,
    ),
    continueOnError: true,
  );

  // Process messages through the full pipeline
  developer.log(
    '🚀 Processing ${messages.length} messages through full pipeline...',
  );

  final stopwatch = Stopwatch()..start();
  final result = await processor.processMessages(messages, config);
  stopwatch.stop();

  // Display results
  developer.log('\n✅ Processing Results:');
  developer.log(
    '  Processed messages: ${result.processedMessages.length}/${messages.length}',
  );
  developer.log('  Created chunks: ${result.chunks.length}');
  developer.log(
    '  Generated embeddings: ${result.embeddingResult?.embeddings.length ?? 0}',
  );
  developer.log('  Processing errors: ${result.errors.length}');
  developer.log('  Success: ${result.isSuccess ? "Yes" : "Partial"}');
  developer.log('  Total time: ${stopwatch.elapsedMilliseconds}ms');

  // Show detailed statistics
  developer.log('\n📊 Detailed Statistics:');
  developer.log(
    '  Success rate: ${(result.stats.successRate * 100).toStringAsFixed(1)}%',
  );
  developer.log(
    '  Average processing time: ${result.stats.processingTimeMs / messages.length}ms/message',
  );

  // Show stage timings
  if (result.stats.stageTimings.isNotEmpty) {
    developer.log('  Stage timings:');
    for (final entry in result.stats.stageTimings.entries) {
      developer.log('    ${entry.key}: ${entry.value}ms');
    }
  }

  // Show health status
  final health = processor.getHealthStatus();
  developer.log('\n🔍 Component Health:');
  health.forEach((component, status) {
    developer.log('  $component: $status');
  });
}

/// Example 4: Preset Configurations
Future<void> presetConfigurationsExample() async {
  developer.log('\n⚙️ Example 4: Preset Configurations');
  developer.log('-' * 40);

  final presets = [
    ('Development', ProcessingPreset.development),
    ('Production', ProcessingPreset.production),
    ('High Throughput', ProcessingPreset.highThroughput),
    ('Low Latency', ProcessingPreset.lowLatency),
    ('Memory Optimized', ProcessingPreset.memoryOptimized),
  ];

  for (final (name, preset) in presets) {
    final config = ProcessingPipelineConfig.fromPreset(preset);

    developer.log('\n🎛️ $name Preset:');
    developer.log('  Processing mode: ${config.processingConfig.mode}');
    developer.log(
      '  Max concurrency: ${config.processingConfig.maxConcurrency}',
    );
    developer.log('  Chunk tokens: ${config.chunkingConfig.maxChunkTokens}');
    developer.log('  Chunking strategy: ${config.chunkingConfig.strategy}');
    developer.log(
      '  Embedding batch size: ${config.embeddingConfig.maxBatchSize}',
    );
    developer.log(
      '  Circuit breaker: ${config.embeddingConfig.circuitBreaker.enabled}',
    );
    developer.log(
      '  Memory limit: ${(config.performanceConfig.memoryLimit / 1024 / 1024).toStringAsFixed(0)}MB',
    );
    developer.log('  Enable caching: ${config.embeddingConfig.enableCaching}');
  }

  // Demonstrate config validation
  developer.log('\n✅ Configuration Validation:');
  try {
    const config = ProcessingPipelineConfig();
    config.validate();
    developer.log('  Default configuration: Valid ✓');
  } catch (e) {
    developer.log('  Default configuration: Invalid ✗ - $e');
  }

  // Show JSON serialization
  final prodConfig = ProcessingPipelineConfig.fromPreset(
    ProcessingPreset.production,
  );
  final json = prodConfig.toJson();
  final restored = ProcessingPipelineConfig.fromJson(json);

  developer.log('  JSON serialization: ${json.keys.length} sections');
  developer.log(
    '  Restoration successful: ${restored.processingConfig.mode == prodConfig.processingConfig.mode}',
  );
}

/// Example 5: Performance Monitoring
Future<void> performanceMonitoringExample() async {
  developer.log('\n📈 Example 5: Performance Monitoring');
  developer.log('-' * 40);

  // Create components with monitoring enabled
  final tokenCounter = HeuristicTokenCounter(charsPerToken: 4);
  final chunker = MessageChunker(tokenCounter: tokenCounter);
  final embeddingService = SimpleEmbeddingService(dimensions: 32);
  final pipeline = EmbeddingPipeline(embeddingService: embeddingService);

  // Create a larger dataset for meaningful statistics
  final messages = List.generate(
    20,
    (i) => Message(
      id: 'perf_msg_$i',
      role: i % 2 == 0 ? MessageRole.user : MessageRole.assistant,
      content:
          'Performance test message $i with some meaningful content to demonstrate processing capabilities and measure throughput.',
      timestamp: DateTime.now(),
    ),
  );

  developer.log(
    '📊 Processing ${messages.length} messages for performance analysis...',
  );

  // Reset statistics
  chunker.resetStatistics();
  pipeline.resetStatistics();

  // Process with different configurations and measure performance
  final configs = [
    ('Small Chunks', ChunkingConfig(maxChunkTokens: 20)),
    ('Medium Chunks', ChunkingConfig(maxChunkTokens: 50)),
    ('Large Chunks', ChunkingConfig(maxChunkTokens: 100)),
  ];

  for (final (name, chunkConfig) in configs) {
    developer.log('\n🔬 Testing $name:');

    final stopwatch = Stopwatch()..start();

    // Process all messages
    final allChunks = <MessageChunk>[];
    for (final message in messages) {
      final chunks = await chunker.chunkMessage(message, chunkConfig);
      allChunks.addAll(chunks);
    }

    // Process embeddings
    const embeddingConfig = EmbeddingConfig(
      processingMode: ProcessingMode.parallel,
      maxBatchSize: 10,
    );
    final embeddingResult = await pipeline.processChunks(
      allChunks,
      embeddingConfig,
    );

    stopwatch.stop();

    // Report performance metrics
    developer.log('  Total time: ${stopwatch.elapsedMilliseconds}ms');
    developer.log(
      '  Messages/sec: ${(messages.length * 1000 / stopwatch.elapsedMilliseconds).toStringAsFixed(1)}',
    );
    developer.log('  Chunks created: ${allChunks.length}');
    developer.log('  Embeddings: ${embeddingResult.embeddings.length}');
    developer.log(
      '  Avg chunk size: ${allChunks.fold<int>(0, (sum, c) => sum + c.content.length) ~/ allChunks.length} chars',
    );
  }

  // Final statistics
  final chunkStats = chunker.getStatistics();
  final pipelineStats = pipeline.getStatistics();

  developer.log('\n📋 Final Performance Summary:');
  developer.log('  Total messages processed: ${chunkStats.totalMessages}');
  developer.log('  Total chunks created: ${chunkStats.totalChunks}');
  developer.log('  Total embeddings generated: ${pipelineStats.totalItems}');
  developer.log(
    '  Overall success rate: ${(pipelineStats.successfulItems / pipelineStats.totalItems * 100).toStringAsFixed(1)}%',
  );
  developer.log(
    '  Average processing time: ${chunkStats.processingTimeMs / chunkStats.totalMessages}ms/message',
  );
  developer.log(
    '  Cache hit rate: ${(pipelineStats.cacheHitRate * 100).toStringAsFixed(1)}%',
  );

  developer.log('\n🎉 Advanced Processing Pipeline Example Complete!');
}

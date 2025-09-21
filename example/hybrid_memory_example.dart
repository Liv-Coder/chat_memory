import 'package:chat_memory/chat_memory.dart';
import 'dart:developer' as developer;

/// Comprehensive examples demonstrating the hybrid memory system
///
/// This file shows various usage patterns for the enhanced chat memory
/// package with summarization and semantic retrieval capabilities.
void main() async {
  developer.log('=== Chat Memory Hybrid System Examples ===\n');

  // Run different examples
  await basicUsageExample();
  await presetConfigurationsExample();
  await advancedBuilderExample();
  await semanticRetrievalExample();
  await conversationStatsExample();

  developer.log('\n=== All Examples Complete ===');
}

/// Example 1: Basic usage with default settings
Future<void> basicUsageExample() async {
  developer.log('📝 Example 1: Basic Usage');
  developer.log('─' * 40);

  // Create a simple memory manager for development
  final manager = await EnhancedConversationManager.create(
    preset: MemoryPreset.development,
    maxTokens: 1000, // Small budget for demo
  );

  // Add some messages to build context
  await manager.appendSystemMessage(
    'You are a helpful assistant specializing in travel planning.',
  );

  await manager.appendUserMessage('I want to plan a trip to Europe');
  await manager.appendAssistantMessage(
    'I\'d be happy to help you plan your European adventure! Europe offers incredible diversity - from historic cities like Rome and Prague to stunning natural landscapes in Norway and Switzerland. What type of experience interests you most?',
  );

  await manager.appendUserMessage('I love history and architecture');
  await manager.appendAssistantMessage(
    'Perfect! Europe has some of the world\'s most spectacular historical sites. I\'d recommend starting with Rome (Colosseum, Vatican), then Athens (Acropolis), Prague (medieval old town), and Barcelona (Gaudí\'s masterpieces). Each city offers unique architectural styles spanning different eras.',
  );

  await manager.appendUserMessage('What about costs and budget planning?');

  // Build prompt with hybrid memory
  final prompt = await manager.buildPrompt(
    clientTokenBudget: 800,
    userQuery: 'budget planning for Europe trip',
  );

  developer.log('Final prompt (${prompt.estimatedTokens} tokens):');
  developer.log(prompt.promptText);
  developer.log('\nSummary: ${prompt.summary ?? "None"}');

  // Get enhanced prompt with semantic info
  final enhancedPrompt = await manager.buildEnhancedPrompt(
    clientTokenBudget: 800,
    userQuery: 'budget planning for Europe trip',
  );

  developer.log(
    '\nSemantic messages retrieved: ${enhancedPrompt.semanticMessages.length}',
  );
  developer.log('Processing metadata: ${enhancedPrompt.metadata}');
  developer.log("");
}

/// Example 2: Using different preset configurations
Future<void> presetConfigurationsExample() async {
  developer.log('⚙️ Example 2: Preset Configurations');
  developer.log('─' * 40);

  // Development preset - fast, in-memory
  developer.log('🔧 Development preset:');
  final devManager = await EnhancedConversationManager.create(
    preset: MemoryPreset.development,
    maxTokens: 2000,
  );
  await _addSampleConversation(devManager);
  await _showStats(devManager, 'Development');

  // Production preset - persistent storage with semantic search
  developer.log('\n🏭 Production preset:');
  final prodManager = await EnhancedConversationManager.create(
    preset: MemoryPreset.production,
    maxTokens: 4000,
    databasePath: 'example_chat_memory.db',
  );
  await _addSampleConversation(prodManager);
  await _showStats(prodManager, 'Production');

  // Minimal preset - only summarization
  developer.log('\n⚡ Minimal preset:');
  final minimalManager = await EnhancedConversationManager.create(
    preset: MemoryPreset.minimal,
    maxTokens: 1500,
  );
  await _addSampleConversation(minimalManager);
  await _showStats(minimalManager, 'Minimal');

  developer.log('');
}

/// Example 3: Advanced builder pattern configuration
Future<void> advancedBuilderExample() async {
  developer.log('🏗️ Example 3: Advanced Builder Configuration');
  developer.log('─' * 40);

  // Use builder pattern for fine-grained control
  final customManager = MemoryManagerBuilder()
      .withMaxTokens(3000)
      .withLocalVectorStore(databasePath: 'custom_vectors.db')
      .withSimpleEmbedding(dimensions: 512)
      .enableSemanticMemory(topK: 7, minSimilarity: 0.25)
      .build();

  final conversationManager = EnhancedConversationManager(
    memoryManager: customManager,
    onSummaryCreated: (summary) {
      developer.log(
        '📄 Summary created: ${summary.content.substring(0, 50)}...',
      );
    },
    onMessageStored: (message) {
      developer.log(
        '💾 Message stored: ${message.role} (${message.content.length} chars)',
      );
    },
  );

  // Add messages and demonstrate callbacks
  await conversationManager.appendSystemMessage(
    'You are an expert software architect.',
  );
  await conversationManager.appendUserMessage(
    'I need help designing a scalable microservices architecture.',
  );
  await conversationManager.appendAssistantMessage(
    'For a scalable microservices architecture, consider these key patterns: API Gateway for routing, Service Discovery for communication, Circuit Breakers for fault tolerance, and Event-Driven Architecture for loose coupling. What\'s your specific use case?',
  );

  final prompt = await conversationManager.buildPrompt(clientTokenBudget: 2000);

  developer.log('\nCustom configuration result:');
  developer.log('Tokens: ${prompt.estimatedTokens}');
  developer.log('Messages included: ${prompt.includedMessages.length}');
  developer.log('');
}

/// Example 4: Semantic retrieval in action
Future<void> semanticRetrievalExample() async {
  developer.log('🔍 Example 4: Semantic Retrieval Demonstration');
  developer.log('─' * 40);

  final manager = await EnhancedConversationManager.create(
    preset: MemoryPreset.production,
    maxTokens: 2000,
  );

  // Build a conversation with various topics
  await manager.appendSystemMessage('You are a knowledgeable assistant.');

  // Topic 1: Cooking
  await manager.appendUserMessage('How do I make pasta carbonara?');
  await manager.appendAssistantMessage(
    'Classic carbonara uses eggs, pecorino cheese, pancetta, and black pepper. The key is to temper the eggs slowly to avoid scrambling.',
  );

  // Topic 2: Programming
  await manager.appendUserMessage('Explain async programming in JavaScript');
  await manager.appendAssistantMessage(
    'Async programming in JS uses Promises and async/await to handle non-blocking operations. This prevents the main thread from freezing during I/O operations.',
  );

  // Topic 3: Fitness
  await manager.appendUserMessage('Best exercises for core strength?');
  await manager.appendAssistantMessage(
    'Effective core exercises include planks, dead bugs, bird dogs, and pallof presses. Focus on stability rather than just crunches.',
  );

  // Topic 4: Travel
  await manager.appendUserMessage('Recommend places to visit in Japan');
  await manager.appendAssistantMessage(
    'Japan offers diverse experiences: Tokyo for modern culture, Kyoto for traditional temples, Osaka for food, and Mount Fuji for natural beauty.',
  );

  // Now ask about cAooking again - should retrieve semantic context
  await manager.appendUserMessage('What about making risotto?');

  final enhancedPrompt = await manager.buildEnhancedPrompt(
    clientTokenBudget: 1800,
    userQuery: 'making risotto cooking techniques',
  );

  developer.log('Query: "making risotto cooking techniques"');
  developer.log(
    'Semantic messages found: ${enhancedPrompt.semanticMessages.length}',
  );

  for (final msg in enhancedPrompt.semanticMessages) {
    final similarity = msg.metadata?['similarity'] ?? 0.0;
    developer.log(
      '  - Similarity: ${similarity.toStringAsFixed(3)} | ${msg.content.substring(0, 60)}...',
    );
  }

  developer.log('\nFull enhanced prompt:');
  developer.log(enhancedPrompt.promptText);
  developer.log('');
}

/// Example 5: Conversation statistics and monitoring
Future<void> conversationStatsExample() async {
  developer.log('📊 Example 5: Conversation Statistics');
  developer.log('─' * 40);

  final manager = await EnhancedConversationManager.create(
    preset: MemoryPreset.production,
    maxTokens: 3000,
  );

  // Build a longer conversation
  await _addExtendedConversation(manager);

  // Get comprehensive stats
  final stats = await manager.getStats();
  developer.log(stats.toString());

  // Generate follow-up questions (if generator is registered)
  final followUps = await manager.generateFollowUpQuestions(max: 3);
  if (followUps.isNotEmpty) {
    developer.log('Suggested follow-up questions:');
    for (int i = 0; i < followUps.length; i++) {
      developer.log('  ${i + 1}. ${followUps[i]}');
    }
  } else {
    developer.log('No follow-up generator registered.');
  }

  developer.log('');
}

/// Helper: Add a sample conversation
Future<void> _addSampleConversation(EnhancedConversationManager manager) async {
  await manager.appendSystemMessage('You are a helpful AI assistant.');
  await manager.appendUserMessage('What is machine learning?');
  await manager.appendAssistantMessage(
    'Machine learning is a subset of AI where algorithms learn patterns from data to make predictions or decisions without explicit programming.',
  );
  await manager.appendUserMessage(
    'How does it differ from traditional programming?',
  );
  await manager.appendAssistantMessage(
    'Traditional programming uses explicit rules, while ML learns rules from data. Instead of writing "if-then" logic, you provide examples and let the algorithm find patterns.',
  );
}

/// Helper: Show basic stats
Future<void> _showStats(
  EnhancedConversationManager manager,
  String preset,
) async {
  final stats = await manager.getStats();
  developer.log(
    '$preset stats: ${stats.totalMessages} messages, ${stats.totalTokens} tokens',
  );

  if (stats.vectorCount != null) {
    developer.log('  Vector store: ${stats.vectorCount} embeddings');
  }
}

/// Helper: Add an extended conversation for stats demo
Future<void> _addExtendedConversation(
  EnhancedConversationManager manager,
) async {
  final topics = [
    ('You are an expert in multiple fields.', MessageRole.system),
    ('Tell me about climate change.', MessageRole.user),
    (
      'Climate change refers to long-term shifts in global temperatures and weather patterns, primarily caused by human activities like burning fossil fuels.',
      MessageRole.assistant,
    ),
    ('What can individuals do to help?', MessageRole.user),
    (
      'Individuals can reduce their carbon footprint by using renewable energy, improving home efficiency, choosing sustainable transportation, and supporting climate-friendly policies.',
      MessageRole.assistant,
    ),
    ('How about renewable energy technologies?', MessageRole.user),
    (
      'Key renewable technologies include solar panels, wind turbines, hydroelectric power, and emerging solutions like tidal and geothermal energy.',
      MessageRole.assistant,
    ),
    ('What are the economic implications?', MessageRole.user),
    (
      'The transition to clean energy creates jobs in new industries while potentially displacing some traditional energy jobs. Overall, studies show net positive economic benefits.',
      MessageRole.assistant,
    ),
    ('How do carbon taxes work?', MessageRole.user),
    (
      'Carbon taxes put a price on carbon emissions, making polluting activities more expensive and incentivizing cleaner alternatives. The revenue can fund green initiatives or be returned to citizens.',
      MessageRole.assistant,
    ),
  ];

  for (final (content, role) in topics) {
    final message = Message(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      role: role,
      content: content,
      timestamp: DateTime.now().toUtc(),
    );
    await manager.appendMessage(message);

    // Add small delay to make timestamps distinct
    await Future.delayed(Duration(milliseconds: 10));
  }
}

/// Example of custom summarization strategy
class CustomSummarizer implements Summarizer {
  @override
  Future<SummaryInfo> summarize(
    List<Message> messages,
    TokenCounter tokenCounter,
  ) async {
    final content = messages.map((m) => m.content).join(' ');
    final summary =
        'Custom summary of ${messages.length} messages: ${content.substring(0, 100)}...';

    return SummaryInfo(
      chunkId: 'custom_${DateTime.now().millisecondsSinceEpoch}',
      summary: summary,
      tokenEstimateBefore: tokenCounter.estimateTokens(content),
      tokenEstimateAfter: tokenCounter.estimateTokens(summary),
    );
  }
}

// Enhanced Follow-up Generator Examples
// Demonstrates the new dynamic and intelligent follow-up generation system

import 'package:chat_memory/chat_memory.dart';
import 'package:chat_memory/src/conversation/follow_up/context_analyzer.dart';
import 'package:chat_memory/src/conversation/follow_up/ai_follow_up_generator.dart';
import 'package:chat_memory/src/conversation/follow_up/domain_specific_generator.dart';
import 'package:chat_memory/src/conversation/follow_up/adaptive_follow_up_generator.dart';

import 'package:flutter/foundation.dart';

void main() async {
  debugPrint('🚀 Enhanced Follow-up Generator Examples\n');

  await demonstrateContextAnalyzer();
  await demonstrateEnhancedHeuristic();
  await demonstrateAIGenerator();
  await demonstrateDomainSpecific();
  await demonstrateAdaptiveLearning();
  await demonstrateCompositeWorkflow();
}

/// Demonstrate the ContextAnalyzer capabilities
Future<void> demonstrateContextAnalyzer() async {
  debugPrint('🧠 Context Analyzer Demonstration');
  debugPrint('=' * 50);

  final analyzer = ContextAnalyzer();

  // Create sample conversation
  final messages = [
    Message(
      id: '1',
      role: MessageRole.user,
      content: 'I want to learn about machine learning algorithms',
      timestamp: DateTime.now().subtract(const Duration(minutes: 10)),
    ),
    Message(
      id: '2',
      role: MessageRole.assistant,
      content:
          'Machine learning algorithms are mathematical models that learn patterns from data. There are supervised, unsupervised, and reinforcement learning approaches.',
      timestamp: DateTime.now().subtract(const Duration(minutes: 9)),
    ),
    Message(
      id: '3',
      role: MessageRole.user,
      content: 'Can you explain supervised learning in more detail?',
      timestamp: DateTime.now().subtract(const Duration(minutes: 5)),
    ),
    Message(
      id: '4',
      role: MessageRole.assistant,
      content:
          'Supervised learning uses labeled training data to learn a mapping function from inputs to outputs. Examples include classification and regression.',
      timestamp: DateTime.now().subtract(const Duration(minutes: 4)),
    ),
  ];

  final context = await analyzer.analyzeContext(messages);

  debugPrint('📊 Analysis Results:');
  debugPrint('  • Topics: ${context.topics.join(', ')}');
  debugPrint('  • Stage: ${context.stage.name}');
  debugPrint('  • Message Type: ${context.lastMessageType.name}');
  debugPrint(
    '  • Engagement Level: ${(context.engagementLevel * 100).round()}%',
  );
  debugPrint('  • Sentiment: ${context.dominantSentiment ?? 'neutral'}');
  debugPrint('  • Momentum: ${(context.momentum * 100).round()}%');
  debugPrint('  • Keywords: ${context.keywords.take(5).join(', ')}');
  debugPrint('');
}

/// Demonstrate enhanced heuristic generator
Future<void> demonstrateEnhancedHeuristic() async {
  debugPrint('🎯 Enhanced Heuristic Generator');
  debugPrint('=' * 50);

  final generator = HeuristicFollowUpGenerator();

  // Educational conversation
  final educationMessages = [
    Message(
      id: '1',
      role: MessageRole.user,
      content: 'I want to understand calculus better',
      timestamp: DateTime.now(),
    ),
    Message(
      id: '2',
      role: MessageRole.assistant,
      content:
          'Calculus deals with rates of change and accumulation. It has two main branches: differential and integral calculus.',
      timestamp: DateTime.now(),
    ),
  ];

  final suggestions = await generator.generate(educationMessages, max: 3);

  debugPrint('📚 Educational Context Suggestions:');
  for (int i = 0; i < suggestions.length; i++) {
    debugPrint('  ${i + 1}. ${suggestions[i]}');
  }
  debugPrint('');
}

/// Demonstrate AI-powered generator
Future<void> demonstrateAIGenerator() async {
  debugPrint('🤖 AI-Powered Generator');
  debugPrint('=' * 50);

  final config = const AIFollowUpConfig(
    provider: 'google',
    enableFallback: true,
    rateLimitPerMinute: 10,
  );

  final generator = AIFollowUpGenerator(config: config);

  // Technical conversation
  final techMessages = [
    Message(
      id: '1',
      role: MessageRole.user,
      content: 'I am having trouble with my React app deployment',
      timestamp: DateTime.now(),
    ),
    Message(
      id: '2',
      role: MessageRole.assistant,
      content:
          'Deployment issues can stem from various sources. What specific error are you encountering?',
      timestamp: DateTime.now(),
    ),
  ];

  try {
    final suggestions = await generator.generate(techMessages, max: 3);

    debugPrint('🔧 Technical Support Suggestions:');
    for (int i = 0; i < suggestions.length; i++) {
      debugPrint('  ${i + 1}. ${suggestions[i]}');
    }
  } catch (e) {
    debugPrint(
      '⚠️  AI Generator Demo (requires API key): ${e.toString().split(':').first}',
    );
    debugPrint(
      '  This would generate context-aware AI suggestions in real usage.',
    );
  }
  debugPrint('');
}

/// Demonstrate domain-specific generator
Future<void> demonstrateDomainSpecific() async {
  debugPrint('🏭 Domain-Specific Generator');
  debugPrint('=' * 50);

  final generator = DomainSpecificGenerator();

  // Business conversation
  final businessMessages = [
    Message(
      id: '1',
      role: MessageRole.user,
      content:
          'We need to develop a marketing strategy for our new product launch',
      timestamp: DateTime.now(),
    ),
    Message(
      id: '2',
      role: MessageRole.assistant,
      content:
          'A successful product launch requires understanding your target market, competitive landscape, and unique value proposition.',
      timestamp: DateTime.now(),
    ),
  ];

  final suggestions = await generator.generate(businessMessages, max: 3);

  debugPrint('💼 Business Domain Suggestions:');
  for (int i = 0; i < suggestions.length; i++) {
    debugPrint('  ${i + 1}. ${suggestions[i]}');
  }

  // Technical conversation
  final debugMessages = [
    Message(
      id: '1',
      role: MessageRole.user,
      content:
          'My application is throwing a null pointer exception in production',
      timestamp: DateTime.now(),
    ),
  ];

  final debugSuggestions = await generator.generate(debugMessages, max: 3);

  debugPrint('');
  debugPrint('🔧 Technical Domain Suggestions:');
  for (int i = 0; i < debugSuggestions.length; i++) {
    debugPrint('  ${i + 1}. ${debugSuggestions[i]}');
  }
  debugPrint('');
}

/// Demonstrate adaptive learning generator
Future<void> demonstrateAdaptiveLearning() async {
  debugPrint('📚 Adaptive Learning Generator');
  debugPrint('=' * 50);

  final generator = AdaptiveFollowUpGenerator();

  // Initial conversation
  final messages = [
    Message(
      id: '1',
      role: MessageRole.user,
      content: 'How do I improve my programming skills?',
      timestamp: DateTime.now(),
    ),
    Message(
      id: '2',
      role: MessageRole.assistant,
      content:
          'Improving programming skills requires practice, reading code, and building projects.',
      timestamp: DateTime.now(),
    ),
  ];

  // Generate initial suggestions
  final suggestions = await generator.generate(messages, max: 3);

  debugPrint('🎓 Initial Learning Suggestions:');
  for (int i = 0; i < suggestions.length; i++) {
    debugPrint('  ${i + 1}. ${suggestions[i]}');
  }

  // Simulate user interactions for learning
  debugPrint('');
  debugPrint('📊 Simulating User Interactions...');

  final analyzer = ContextAnalyzer();
  final context = await analyzer.analyzeContext(messages);

  // Record positive interaction
  await generator.recordInteraction(
    suggestionId: '1',
    suggestion: suggestions.first,
    context: context,
    action: UserAction.selected,
    relevanceScore: 0.9,
  );

  debugPrint('  ✅ User selected: "${suggestions.first}"');
  debugPrint('  📈 System learning from positive feedback...');

  // Record negative interaction
  if (suggestions.length > 1) {
    await generator.recordInteraction(
      suggestionId: '2',
      suggestion: suggestions[1],
      context: context,
      action: UserAction.ignored,
      relevanceScore: 0.2,
    );
    debugPrint('  ❌ User ignored: "${suggestions[1]}"');
    debugPrint('  📉 System learning from negative feedback...');
  }

  debugPrint('  🧠 Adaptive generator now personalizes future suggestions');
  debugPrint('');
}

/// Demonstrate composite workflow
Future<void> demonstrateCompositeWorkflow() async {
  debugPrint('🔄 Composite Generator Workflow');
  debugPrint('=' * 50);

  // This demonstrates how multiple generators can work together
  debugPrint('💡 Multi-Strategy Follow-up Generation:');
  debugPrint('');

  final messages = [
    Message(
      id: '1',
      role: MessageRole.user,
      content: 'I need help with financial planning for retirement',
      timestamp: DateTime.now(),
    ),
    Message(
      id: '2',
      role: MessageRole.assistant,
      content:
          'Retirement planning involves setting goals, understanding your timeline, and choosing appropriate investment strategies.',
      timestamp: DateTime.now(),
    ),
  ];

  // Enhanced heuristic
  final heuristicGen = HeuristicFollowUpGenerator();
  final heuristicSuggestions = await heuristicGen.generate(messages, max: 2);

  debugPrint('🎯 Enhanced Heuristic:');
  for (final suggestion in heuristicSuggestions) {
    debugPrint('  • $suggestion');
  }
  debugPrint('');

  // Domain-specific
  final domainGen = DomainSpecificGenerator();
  final domainSuggestions = await domainGen.generate(messages, max: 2);

  debugPrint('🏗️ Domain-Specific (Business):');
  for (final suggestion in domainSuggestions) {
    debugPrint('  • $suggestion');
  }
  debugPrint('');

  // AI-powered (mock)
  debugPrint('🤖 AI-Powered (Simulated):');
  debugPrint('  • What is your target retirement age and expected lifestyle?');
  debugPrint('  • Have you considered tax-advantaged retirement accounts?');
  debugPrint('');

  debugPrint(
    '🎊 Composite Result: Intelligent, diverse, context-aware suggestions',
  );
  debugPrint('   combining multiple strategies for optimal user experience!');
  debugPrint('');

  debugPrint('✨ Enhanced Follow-up Generator System Features:');
  debugPrint('  ✅ Context-aware analysis of conversation flow');
  debugPrint(
    '  ✅ Multiple generation strategies (heuristic, AI, domain, adaptive)',
  );
  debugPrint('  ✅ Intelligent fallback mechanisms');
  debugPrint('  ✅ Learning from user interactions');
  debugPrint('  ✅ Domain-specific templates and patterns');
  debugPrint('  ✅ Seamless integration with ChatMemory facade');
}

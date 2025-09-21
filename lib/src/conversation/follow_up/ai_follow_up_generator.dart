import 'dart:async';
import 'dart:convert';

import '../../core/models/message.dart';
import '../../core/errors.dart';
import '../../core/logging/chat_memory_logger.dart';
import 'follow_up_generator.dart';
import 'context_analyzer.dart';

/// Configuration for AI-powered follow-up generation
class AIFollowUpConfig {
  final String? apiKey;
  final String model;
  final String provider;
  final int maxTokens;
  final double temperature;
  final Duration timeout;
  final int rateLimitPerMinute;
  final bool enableFallback;

  const AIFollowUpConfig({
    this.apiKey,
    this.model = 'gemini-pro',
    this.provider = 'google',
    this.maxTokens = 150,
    this.temperature = 0.7,
    this.timeout = const Duration(seconds: 10),
    this.rateLimitPerMinute = 20,
    this.enableFallback = true,
  });
}

/// AI-powered follow-up generator with context awareness and fallback
class AIFollowUpGenerator implements FollowUpGenerator {
  static final _logger = ChatMemoryLogger.loggerFor('ai_follow_up_generator');

  final AIFollowUpConfig config;
  final ContextAnalyzer _contextAnalyzer;
  final FollowUpGenerator _fallbackGenerator;
  final List<DateTime> _requestTimes = [];
  final Map<String, List<String>> _cache = {};

  AIFollowUpGenerator({
    required this.config,
    ContextAnalyzer? contextAnalyzer,
    FollowUpGenerator? fallbackGenerator,
  }) : _contextAnalyzer = contextAnalyzer ?? ContextAnalyzer(),
       _fallbackGenerator = fallbackGenerator ?? HeuristicFollowUpGenerator();

  @override
  Future<List<String>> generate(List<Message> messages, {int max = 3}) async {
    final sw = ChatMemoryLogger.logOperationStart(
      _logger,
      'generate',
      params: {'messageCount': messages.length, 'max': max},
    );

    try {
      // Check rate limiting
      if (!_checkRateLimit()) {
        _logger.warning(
          'Rate limit exceeded, falling back to heuristic generator',
        );
        return await _useFallback(messages, max);
      }

      // Check cache
      final cacheKey = _generateCacheKey(messages, max);
      if (_cache.containsKey(cacheKey)) {
        _logger.fine('Using cached AI response');
        return _cache[cacheKey]!;
      }

      // Analyze context
      final context = await _contextAnalyzer.analyzeContext(messages);

      // Generate AI suggestions
      final suggestions = await _generateAISuggestions(messages, context, max);

      // Cache successful response
      _cache[cacheKey] = suggestions;

      ChatMemoryLogger.logOperationEnd(
        _logger,
        'generate',
        sw,
        result: {'source': 'ai', 'suggestionCount': suggestions.length},
      );

      return suggestions;
    } catch (error, stackTrace) {
      ChatMemoryLogger.logError(
        _logger,
        'generate',
        error,
        stackTrace: stackTrace,
        shouldRethrow: false,
      );

      if (config.enableFallback) {
        _logger.info('AI generation failed, using fallback generator');
        return await _useFallback(messages, max);
      } else {
        return [];
      }
    }
  }

  /// Generate AI-powered suggestions using mock provider
  Future<List<String>> _generateAISuggestions(
    List<Message> messages,
    ConversationContext context,
    int max,
  ) async {
    try {
      _recordRequest();

      // Simulate AI API call with context-aware responses
      await Future.delayed(Duration(milliseconds: 500));

      if (config.apiKey == null) {
        throw ConfigurationException.missing('apiKey');
      }

      final response = _mockAIResponse(context, max);
      final suggestions = _parseAIResponse(response);

      return suggestions.take(max).toList();
    } on TimeoutException {
      throw ChatMemoryException(
        'AI request timeout after ${config.timeout}',
        context: const ErrorContext(
          component: 'ai_follow_up_generator',
          operation: 'generateAISuggestions',
        ),
      );
    } catch (error) {
      throw ChatMemoryException(
        'AI generation failed: $error',
        cause: error,
        context: const ErrorContext(
          component: 'ai_follow_up_generator',
          operation: 'generateAISuggestions',
        ),
      );
    }
  }

  // _buildContextAwarePrompt removed — unused private helper.

  /// Mock AI response based on context (placeholder for real implementation)
  String _mockAIResponse(ConversationContext context, int max) {
    final responses = <String>[];

    switch (context.stage) {
      case ConversationStage.opening:
        responses.addAll([
          'What specific aspect would you like to explore?',
          'Can you tell me more about your goals?',
          'What is your experience with this topic?',
        ]);
        break;
      case ConversationStage.development:
        responses.addAll([
          'Would you like me to dive deeper into this?',
          'Should we explore related concepts?',
          'How does this fit your objectives?',
        ]);
        break;
      case ConversationStage.clarification:
        responses.addAll([
          'Which part needs more clarification?',
          'Would a different approach help?',
          'Should I provide more examples?',
        ]);
        break;
      case ConversationStage.closing:
        responses.addAll([
          'Are there any final questions?',
          'Would you like a summary?',
          'How can I help you implement this?',
        ]);
        break;
      default:
        responses.addAll([
          'What would you like to know more about?',
          'Should we explore this further?',
          'Are there other aspects to consider?',
        ]);
    }

    responses.shuffle();
    return jsonEncode(responses.take(max).toList());
  }

  /// Parse AI response and extract suggestions
  List<String> _parseAIResponse(String response) {
    try {
      final parsed = jsonDecode(response) as List;
      return parsed.map((item) => item.toString().trim()).toList();
    } catch (error) {
      _logger.warning('Failed to parse AI response: $error');
      return ['What would you like to explore further?'];
    }
  }

  /// Use fallback generator
  Future<List<String>> _useFallback(List<Message> messages, int max) async {
    return await _fallbackGenerator.generate(messages, max: max);
  }

  /// Check rate limiting
  bool _checkRateLimit() {
    final now = DateTime.now();
    final oneMinuteAgo = now.subtract(const Duration(minutes: 1));

    _requestTimes.removeWhere((time) => time.isBefore(oneMinuteAgo));
    return _requestTimes.length < config.rateLimitPerMinute;
  }

  /// Record a request for rate limiting
  void _recordRequest() {
    _requestTimes.add(DateTime.now());
  }

  /// Generate cache key for conversation
  String _generateCacheKey(List<Message> messages, int max) {
    if (messages.isEmpty) return 'empty_$max';

    final recentMessages = messages.length > 3
        ? messages.sublist(messages.length - 3)
        : messages;

    final contentHash = recentMessages
        .map((m) => '${m.role.name}:${m.content.hashCode}')
        .join('|');

    return '${contentHash}_$max'.hashCode.toString();
  }
}

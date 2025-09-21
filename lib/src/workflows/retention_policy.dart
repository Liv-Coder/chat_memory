import 'dart:math' as math;
import 'package:logging/logging.dart';

import '../core/models/message.dart';
import '../core/errors.dart';
import '../core/logging/chat_memory_logger.dart';

/// Retention decision for a message or session
class RetentionDecision {
  /// Whether to retain the item
  final bool shouldRetain;

  /// Reason for the decision
  final String reason;

  /// Priority score (higher = more important to retain)
  final double priority;

  /// Suggested action if not retained
  final RetentionAction suggestedAction;

  /// Additional metadata for the decision
  final Map<String, dynamic> metadata;

  const RetentionDecision({
    required this.shouldRetain,
    required this.reason,
    required this.priority,
    required this.suggestedAction,
    this.metadata = const {},
  });

  RetentionDecision.retain({
    required this.reason,
    required this.priority,
    this.metadata = const {},
  }) : shouldRetain = true,
       suggestedAction = RetentionAction.keep;

  RetentionDecision.remove({
    required this.reason,
    required this.suggestedAction,
    this.priority = 0.0,
    this.metadata = const {},
  }) : shouldRetain = false;
}

/// Actions to take when retention policy determines item should not be retained
enum RetentionAction {
  keep, // Keep the item
  archive, // Move to archive storage
  delete, // Delete permanently
  compress, // Compress or summarize
}

/// Result of evaluating retention policies
class RetentionResult {
  /// Total items evaluated
  final int totalEvaluated;

  /// Items to retain
  final List<String> toRetain;

  /// Items to archive
  final List<String> toArchive;

  /// Items to delete
  final List<String> toDelete;

  /// Items to compress
  final List<String> toCompress;

  /// Detailed decisions for each item
  final Map<String, RetentionDecision> decisions;

  /// Policy evaluation metrics
  final Map<String, dynamic> metrics;

  const RetentionResult({
    required this.totalEvaluated,
    required this.toRetain,
    required this.toArchive,
    required this.toDelete,
    required this.toCompress,
    required this.decisions,
    required this.metrics,
  });
}

/// Base interface for retention policies
abstract class RetentionPolicy {
  /// Unique identifier for this policy
  String get id;

  /// Human-readable description
  String get description;

  /// Priority of this policy (higher = more important)
  int get priority;

  /// Evaluate whether a message should be retained
  Future<RetentionDecision> evaluateMessage(
    Message message, {
    Map<String, dynamic>? context,
  });

  /// Evaluate whether a session should be retained
  Future<RetentionDecision> evaluateSession(
    String sessionId, {
    Map<String, dynamic>? context,
  });

  /// Validate policy configuration
  void validate() {}
}

/// Time-based retention policy
class TimeBasedRetentionPolicy implements RetentionPolicy {
  @override
  final String id;

  @override
  final String description;

  @override
  final int priority;

  /// Maximum age before archiving
  final Duration archiveAfter;

  /// Maximum age before deletion
  final Duration deleteAfter;

  /// Grace period for recent activity
  final Duration gracePeriod;

  const TimeBasedRetentionPolicy({
    required this.id,
    this.description = 'Time-based retention policy',
    this.priority = 100,
    required this.archiveAfter,
    required this.deleteAfter,
    this.gracePeriod = const Duration(hours: 24),
  });

  @override
  Future<RetentionDecision> evaluateMessage(
    Message message, {
    Map<String, dynamic>? context,
  }) async {
    final now = DateTime.now();
    final age = now.difference(message.timestamp);

    if (age > deleteAfter) {
      return RetentionDecision.remove(
        reason:
            'Message older than deletion threshold (${deleteAfter.inDays} days)',
        suggestedAction: RetentionAction.delete,
        metadata: {'age': age.inDays},
      );
    }

    if (age > archiveAfter) {
      return RetentionDecision.remove(
        reason:
            'Message older than archive threshold (${archiveAfter.inDays} days)',
        suggestedAction: RetentionAction.archive,
        metadata: {'age': age.inDays},
      );
    }

    final priority = _calculateTimePriority(age);
    return RetentionDecision.retain(
      reason: 'Message within retention period',
      priority: priority,
      metadata: {'age': age.inDays},
    );
  }

  @override
  Future<RetentionDecision> evaluateSession(
    String sessionId, {
    Map<String, dynamic>? context,
  }) async {
    final lastAccessed = context?['lastAccessedAt'] as DateTime?;
    if (lastAccessed == null) {
      return RetentionDecision.retain(
        reason: 'No access time available',
        priority: 0.5,
      );
    }

    final age = DateTime.now().difference(lastAccessed);

    if (age > deleteAfter) {
      return RetentionDecision.remove(
        reason: 'Session inactive for ${age.inDays} days',
        suggestedAction: RetentionAction.delete,
        metadata: {'inactiveFor': age.inDays},
      );
    }

    if (age > archiveAfter) {
      return RetentionDecision.remove(
        reason: 'Session inactive for ${age.inDays} days',
        suggestedAction: RetentionAction.archive,
        metadata: {'inactiveFor': age.inDays},
      );
    }

    return RetentionDecision.retain(
      reason: 'Session recently active',
      priority: _calculateTimePriority(age),
      metadata: {'inactiveFor': age.inDays},
    );
  }

  @override
  void validate() {
    if (archiveAfter >= deleteAfter) {
      throw ConfigurationException(
        'Archive threshold must be less than delete threshold',
        context: ErrorContext(
          operation: 'validate',
          component: 'TimeBasedRetentionPolicy',
          params: {
            'archiveAfter': archiveAfter.inDays,
            'deleteAfter': deleteAfter.inDays,
          },
        ),
      );
    }
  }

  double _calculateTimePriority(Duration age) {
    // More recent = higher priority
    final daysSinceCreation = age.inDays.toDouble();
    return math.max(0.0, 1.0 - (daysSinceCreation / deleteAfter.inDays));
  }
}

/// Size-based retention policy
class SizeBasedRetentionPolicy implements RetentionPolicy {
  @override
  final String id;

  @override
  final String description;

  @override
  final int priority;

  /// Maximum total size in bytes
  final int maxTotalSize;

  /// Maximum number of messages
  final int maxMessageCount;

  /// Target size after cleanup (percentage of max)
  final double targetSizeRatio;

  const SizeBasedRetentionPolicy({
    required this.id,
    this.description = 'Size-based retention policy',
    this.priority = 200,
    required this.maxTotalSize,
    required this.maxMessageCount,
    this.targetSizeRatio = 0.8,
  });

  @override
  Future<RetentionDecision> evaluateMessage(
    Message message, {
    Map<String, dynamic>? context,
  }) async {
    final currentSize = context?['currentTotalSize'] as int? ?? 0;
    final currentCount = context?['currentMessageCount'] as int? ?? 0;
    final messageSize = _estimateMessageSize(message);

    // If we're over limits, prioritize by message size and age
    if (currentSize > maxTotalSize || currentCount > maxMessageCount) {
      final sizePriority = _calculateSizePriority(messageSize);
      final agePriority = _calculateAgePriority(message.timestamp);
      final combinedPriority = (sizePriority + agePriority) / 2;

      if (combinedPriority < 0.3) {
        return RetentionDecision.remove(
          reason: 'Low priority message in oversized storage',
          suggestedAction: RetentionAction.archive,
          metadata: {
            'messageSize': messageSize,
            'sizePriority': sizePriority,
            'agePriority': agePriority,
          },
        );
      }
    }

    return RetentionDecision.retain(
      reason: 'Storage within limits or high priority message',
      priority: _calculateSizePriority(messageSize),
      metadata: {'messageSize': messageSize},
    );
  }

  @override
  Future<RetentionDecision> evaluateSession(
    String sessionId, {
    Map<String, dynamic>? context,
  }) async {
    final sessionSize = context?['sessionSize'] as int? ?? 0;
    final messageCount = context?['messageCount'] as int? ?? 0;

    if (sessionSize > maxTotalSize * 0.1) {
      // Large session
      return RetentionDecision.remove(
        reason: 'Large session consuming significant storage',
        suggestedAction: RetentionAction.archive,
        metadata: {'sessionSize': sessionSize, 'messageCount': messageCount},
      );
    }

    return RetentionDecision.retain(
      reason: 'Session size within limits',
      priority: 1.0 - (sessionSize / maxTotalSize),
      metadata: {'sessionSize': sessionSize},
    );
  }

  @override
  void validate() {
    Validation.validatePositive('maxTotalSize', maxTotalSize);
    Validation.validatePositive('maxMessageCount', maxMessageCount);
    Validation.validateRange(
      'targetSizeRatio',
      targetSizeRatio,
      min: 0.1,
      max: 1.0,
    );
  }

  int _estimateMessageSize(Message message) {
    return message.content.length * 2 + // UTF-16 encoding
        message.id.length * 2 +
        message.role.toString().length * 2 +
        100; // Overhead
  }

  double _calculateSizePriority(int messageSize) {
    // Smaller messages get higher priority
    final sizeKB = messageSize / 1024.0;
    return math.max(0.0, 1.0 - (sizeKB / 100.0)); // Normalize to 100KB max
  }

  double _calculateAgePriority(DateTime timestamp) {
    final age = DateTime.now().difference(timestamp);
    final ageInDays = age.inDays.toDouble();
    return math.max(0.0, 1.0 - (ageInDays / 365.0)); // Normalize to 1 year
  }
}

/// Usage-based retention policy
class UsageBasedRetentionPolicy implements RetentionPolicy {
  @override
  final String id;

  @override
  final String description;

  @override
  final int priority;

  /// Minimum access count to retain
  final int minAccessCount;

  /// Minimum importance score to retain
  final double minImportanceScore;

  /// Weight for access frequency in priority calculation
  final double accessWeight;

  /// Weight for recency in priority calculation
  final double recencyWeight;

  const UsageBasedRetentionPolicy({
    required this.id,
    this.description = 'Usage-based retention policy',
    this.priority = 300,
    this.minAccessCount = 2,
    this.minImportanceScore = 0.1,
    this.accessWeight = 0.6,
    this.recencyWeight = 0.4,
  });

  @override
  Future<RetentionDecision> evaluateMessage(
    Message message, {
    Map<String, dynamic>? context,
  }) async {
    final accessCount = context?['accessCount'] as int? ?? 0;
    final lastAccessedAt = context?['lastAccessedAt'] as DateTime?;
    final importanceScore = _calculateImportanceScore(message, context);

    if (accessCount < minAccessCount && importanceScore < minImportanceScore) {
      return RetentionDecision.remove(
        reason: 'Low usage and importance score',
        suggestedAction: RetentionAction.archive,
        metadata: {
          'accessCount': accessCount,
          'importanceScore': importanceScore,
        },
      );
    }

    final priority = _calculateUsagePriority(
      accessCount,
      lastAccessedAt,
      importanceScore,
    );
    return RetentionDecision.retain(
      reason: 'Sufficient usage or importance',
      priority: priority,
      metadata: {
        'accessCount': accessCount,
        'importanceScore': importanceScore,
        'priority': priority,
      },
    );
  }

  @override
  Future<RetentionDecision> evaluateSession(
    String sessionId, {
    Map<String, dynamic>? context,
  }) async {
    final accessCount = context?['accessCount'] as int? ?? 0;
    final messageCount = context?['messageCount'] as int? ?? 0;
    final lastAccessedAt = context?['lastAccessedAt'] as DateTime?;

    if (accessCount < minAccessCount && messageCount < 5) {
      return RetentionDecision.remove(
        reason: 'Low usage session with few messages',
        suggestedAction: RetentionAction.delete,
        metadata: {'accessCount': accessCount, 'messageCount': messageCount},
      );
    }

    final priority = _calculateSessionUsagePriority(
      accessCount,
      messageCount,
      lastAccessedAt,
    );
    return RetentionDecision.retain(
      reason: 'Active or valuable session',
      priority: priority,
      metadata: {
        'accessCount': accessCount,
        'messageCount': messageCount,
        'priority': priority,
      },
    );
  }

  @override
  void validate() {
    Validation.validateNonNegative('minAccessCount', minAccessCount);
    Validation.validateRange(
      'minImportanceScore',
      minImportanceScore,
      min: 0.0,
      max: 1.0,
    );
    Validation.validateRange('accessWeight', accessWeight, min: 0.0, max: 1.0);
    Validation.validateRange(
      'recencyWeight',
      recencyWeight,
      min: 0.0,
      max: 1.0,
    );
  }

  double _calculateImportanceScore(
    Message message,
    Map<String, dynamic>? context,
  ) {
    // Simple importance scoring based on content length and keywords
    final contentLength = message.content.length;
    final lengthScore = math.min(contentLength / 1000.0, 1.0);

    // Check for important keywords
    final importantWords = ['error', 'important', 'critical', 'urgent', 'help'];
    final content = message.content.toLowerCase();
    final keywordScore =
        importantWords.where(content.contains).length / importantWords.length;

    return (lengthScore * 0.7) + (keywordScore * 0.3);
  }

  double _calculateUsagePriority(
    int accessCount,
    DateTime? lastAccessed,
    double importanceScore,
  ) {
    final accessPriority = math.min(
      accessCount / 10.0,
      1.0,
    ); // Normalize to 10 accesses

    double recencyPriority = 0.5;
    if (lastAccessed != null) {
      final daysSinceAccess = DateTime.now().difference(lastAccessed).inDays;
      recencyPriority = math.max(
        0.0,
        1.0 - (daysSinceAccess / 30.0),
      ); // 30 day window
    }

    return (accessPriority * accessWeight) +
        (recencyPriority * recencyWeight) +
        (importanceScore * 0.2);
  }

  double _calculateSessionUsagePriority(
    int accessCount,
    int messageCount,
    DateTime? lastAccessed,
  ) {
    final accessPriority = math.min(accessCount / 5.0, 1.0);
    final sizePriority = math.min(messageCount / 50.0, 1.0);

    double recencyPriority = 0.5;
    if (lastAccessed != null) {
      final daysSinceAccess = DateTime.now().difference(lastAccessed).inDays;
      recencyPriority = math.max(0.0, 1.0 - (daysSinceAccess / 30.0));
    }

    return (accessPriority * 0.4) +
        (sizePriority * 0.2) +
        (recencyPriority * 0.4);
  }
}

/// Composite retention policy that combines multiple policies
class CompositeRetentionPolicy implements RetentionPolicy {
  @override
  final String id;

  @override
  final String description;

  @override
  final int priority;

  /// Component policies
  final List<RetentionPolicy> policies;

  /// How to combine policy decisions
  final PolicyCombinationMode combinationMode;

  /// Minimum number of policies that must agree for a decision
  final int? consensusThreshold;

  const CompositeRetentionPolicy({
    required this.id,
    this.description = 'Composite retention policy',
    this.priority = 1000,
    required this.policies,
    this.combinationMode = PolicyCombinationMode.weighted,
    this.consensusThreshold,
  });

  @override
  Future<RetentionDecision> evaluateMessage(
    Message message, {
    Map<String, dynamic>? context,
  }) async {
    final decisions = <RetentionDecision>[];

    for (final policy in policies) {
      try {
        final decision = await policy.evaluateMessage(
          message,
          context: context,
        );
        decisions.add(decision);
      } catch (e) {
        // Continue with other policies if one fails
      }
    }

    return _combineDecisions(decisions, 'message', message.id);
  }

  @override
  Future<RetentionDecision> evaluateSession(
    String sessionId, {
    Map<String, dynamic>? context,
  }) async {
    final decisions = <RetentionDecision>[];

    for (final policy in policies) {
      try {
        final decision = await policy.evaluateSession(
          sessionId,
          context: context,
        );
        decisions.add(decision);
      } catch (e) {
        // Continue with other policies if one fails
      }
    }

    return _combineDecisions(decisions, 'session', sessionId);
  }

  @override
  void validate() {
    if (policies.isEmpty) {
      throw ConfigurationException(
        'Composite policy must have at least one component policy',
        context: ErrorContext(
          operation: 'validate',
          component: 'CompositeRetentionPolicy',
        ),
      );
    }

    for (final policy in policies) {
      policy.validate();
    }
  }

  RetentionDecision _combineDecisions(
    List<RetentionDecision> decisions,
    String type,
    String id,
  ) {
    if (decisions.isEmpty) {
      return RetentionDecision.retain(
        reason: 'No policy decisions available',
        priority: 0.5,
      );
    }

    switch (combinationMode) {
      case PolicyCombinationMode.unanimous:
        return _unanimousDecision(decisions, type, id);
      case PolicyCombinationMode.majority:
        return _majorityDecision(decisions, type, id);
      case PolicyCombinationMode.weighted:
        return _weightedDecision(decisions, type, id);
      case PolicyCombinationMode.strictest:
        return _strictestDecision(decisions, type, id);
    }
  }

  RetentionDecision _unanimousDecision(
    List<RetentionDecision> decisions,
    String type,
    String id,
  ) {
    final shouldRetain = decisions.every((d) => d.shouldRetain);
    final avgPriority =
        decisions.map((d) => d.priority).reduce((a, b) => a + b) /
        decisions.length;

    if (shouldRetain) {
      return RetentionDecision.retain(
        reason: 'All policies agree to retain',
        priority: avgPriority,
        metadata: {'agreementCount': decisions.length},
      );
    } else {
      final mostCommonAction = _getMostCommonAction(
        decisions.where((d) => !d.shouldRetain),
      );
      return RetentionDecision.remove(
        reason: 'One or more policies recommend removal',
        suggestedAction: mostCommonAction,
        metadata: {
          'disagreementCount': decisions.where((d) => !d.shouldRetain).length,
        },
      );
    }
  }

  RetentionDecision _majorityDecision(
    List<RetentionDecision> decisions,
    String type,
    String id,
  ) {
    final retainCount = decisions.where((d) => d.shouldRetain).length;
    final shouldRetain = retainCount > decisions.length / 2;

    if (shouldRetain) {
      final retainDecisions = decisions.where((d) => d.shouldRetain);
      final avgPriority =
          retainDecisions.map((d) => d.priority).reduce((a, b) => a + b) /
          retainDecisions.length;
      return RetentionDecision.retain(
        reason: 'Majority of policies recommend retention',
        priority: avgPriority,
        metadata: {'retainVotes': retainCount, 'totalVotes': decisions.length},
      );
    } else {
      final removeDecisions = decisions.where((d) => !d.shouldRetain);
      final mostCommonAction = _getMostCommonAction(removeDecisions);
      return RetentionDecision.remove(
        reason: 'Majority of policies recommend removal',
        suggestedAction: mostCommonAction,
        metadata: {
          'removeVotes': decisions.length - retainCount,
          'totalVotes': decisions.length,
        },
      );
    }
  }

  RetentionDecision _weightedDecision(
    List<RetentionDecision> decisions,
    String type,
    String id,
  ) {
    double totalWeight = 0.0;
    double retainWeight = 0.0;

    for (int i = 0; i < decisions.length; i++) {
      final weight = policies[i].priority.toDouble();
      totalWeight += weight;
      if (decisions[i].shouldRetain) {
        retainWeight += weight * decisions[i].priority;
      }
    }

    final shouldRetain = retainWeight > totalWeight / 2;
    final priority = retainWeight / totalWeight;

    if (shouldRetain) {
      return RetentionDecision.retain(
        reason: 'Weighted decision favors retention',
        priority: priority,
        metadata: {'weightedScore': priority},
      );
    } else {
      final removeDecisions = decisions.where((d) => !d.shouldRetain);
      final mostCommonAction = _getMostCommonAction(removeDecisions);
      return RetentionDecision.remove(
        reason: 'Weighted decision favors removal',
        suggestedAction: mostCommonAction,
        metadata: {'weightedScore': 1.0 - priority},
      );
    }
  }

  RetentionDecision _strictestDecision(
    List<RetentionDecision> decisions,
    String type,
    String id,
  ) {
    // If any policy says remove, then remove
    final removeDecisions = decisions.where((d) => !d.shouldRetain);
    if (removeDecisions.isNotEmpty) {
      final mostStrictAction = _getMostStrictAction(removeDecisions);
      return RetentionDecision.remove(
        reason: 'Strictest policy recommends removal',
        suggestedAction: mostStrictAction,
        metadata: {'removePolicies': removeDecisions.length},
      );
    }

    final avgPriority =
        decisions.map((d) => d.priority).reduce((a, b) => a + b) /
        decisions.length;
    return RetentionDecision.retain(
      reason: 'All policies allow retention',
      priority: avgPriority,
      metadata: {'retainPolicies': decisions.length},
    );
  }

  RetentionAction _getMostCommonAction(Iterable<RetentionDecision> decisions) {
    final actionCounts = <RetentionAction, int>{};
    for (final decision in decisions) {
      actionCounts[decision.suggestedAction] =
          (actionCounts[decision.suggestedAction] ?? 0) + 1;
    }

    return actionCounts.entries.reduce((a, b) => a.value > b.value ? a : b).key;
  }

  RetentionAction _getMostStrictAction(Iterable<RetentionDecision> decisions) {
    // Delete > Archive > Compress > Keep
    if (decisions.any((d) => d.suggestedAction == RetentionAction.delete)) {
      return RetentionAction.delete;
    }
    if (decisions.any((d) => d.suggestedAction == RetentionAction.archive)) {
      return RetentionAction.archive;
    }
    if (decisions.any((d) => d.suggestedAction == RetentionAction.compress)) {
      return RetentionAction.compress;
    }
    return RetentionAction.keep;
  }
}

/// How to combine decisions from multiple policies
enum PolicyCombinationMode {
  unanimous, // All policies must agree
  majority, // Majority rules
  weighted, // Weighted by policy priority
  strictest, // Most restrictive policy wins
}

/// Policy evaluator that applies retention policies to messages and sessions
class PolicyEvaluator {
  final List<RetentionPolicy> policies;
  final Logger _logger;

  PolicyEvaluator({required this.policies, Logger? logger})
    : _logger = logger ?? ChatMemoryLogger.loggerFor('PolicyEvaluator') {
    // Sort policies by priority (highest first)
    policies.sort((a, b) => b.priority.compareTo(a.priority));

    // Validate all policies
    for (final policy in policies) {
      policy.validate();
    }
  }

  /// Evaluate retention for a list of messages
  Future<RetentionResult> evaluateMessages(
    List<Message> messages, {
    Map<String, dynamic>? globalContext,
  }) async {
    final decisions = <String, RetentionDecision>{};
    final toRetain = <String>[];
    final toArchive = <String>[];
    final toDelete = <String>[];
    final toCompress = <String>[];

    try {
      for (final message in messages) {
        var finalDecision = RetentionDecision.retain(
          reason: 'Default retention',
          priority: 0.5,
        );

        // Apply each policy and use the highest priority decision
        for (final policy in policies) {
          try {
            final decision = await policy.evaluateMessage(
              message,
              context: globalContext,
            );

            if (decision.priority > finalDecision.priority) {
              finalDecision = decision;
            }
          } catch (e) {
            _logger.warning(
              'Policy ${policy.id} failed for message ${message.id}: $e',
            );
          }
        }

        decisions[message.id] = finalDecision;

        if (finalDecision.shouldRetain) {
          toRetain.add(message.id);
        } else {
          switch (finalDecision.suggestedAction) {
            case RetentionAction.archive:
              toArchive.add(message.id);
              break;
            case RetentionAction.delete:
              toDelete.add(message.id);
              break;
            case RetentionAction.compress:
              toCompress.add(message.id);
              break;
            case RetentionAction.keep:
              toRetain.add(message.id);
              break;
          }
        }
      }

      return RetentionResult(
        totalEvaluated: messages.length,
        toRetain: toRetain,
        toArchive: toArchive,
        toDelete: toDelete,
        toCompress: toCompress,
        decisions: decisions,
        metrics: {
          'retainCount': toRetain.length,
          'archiveCount': toArchive.length,
          'deleteCount': toDelete.length,
          'compressCount': toCompress.length,
          'evaluationTime': DateTime.now().toUtc().toIso8601String(),
        },
      );
    } catch (e, stackTrace) {
      ChatMemoryLogger.logError(
        _logger,
        'evaluateMessages',
        e,
        stackTrace: stackTrace,
        params: {'messageCount': messages.length},
        shouldRethrow: true,
      );
      rethrow;
    }
  }
}

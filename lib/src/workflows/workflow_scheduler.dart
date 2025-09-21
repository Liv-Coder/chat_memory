import 'dart:async';
import 'dart:math' as math;
import 'package:logging/logging.dart';

import 'memory_optimizer.dart';
import 'session_manager.dart';
import 'retention_policy.dart';
import '../core/models/message.dart';
import '../core/errors.dart';
import '../core/logging/chat_memory_logger.dart';

/// Workflow trigger types
enum TriggerType {
  time, // Time-based trigger (cron-like)
  threshold, // Memory/usage threshold trigger
  event, // Event-based trigger
  manual, // Manual execution
}

/// Workflow execution status
enum WorkflowStatus {
  pending,
  running,
  completed,
  failed,
  cancelled,
  suspended,
}

/// Workflow priority levels
enum WorkflowPriority {
  low(1),
  normal(5),
  high(10),
  critical(20);

  const WorkflowPriority(this.value);
  final int value;
}

/// Trigger configuration for workflows
class WorkflowTrigger {
  final String id;
  final TriggerType type;
  final Map<String, dynamic> config;
  final bool enabled;
  final DateTime? nextExecution;

  const WorkflowTrigger({
    required this.id,
    required this.type,
    required this.config,
    this.enabled = true,
    this.nextExecution,
  });

  WorkflowTrigger copyWith({
    bool? enabled,
    DateTime? nextExecution,
    Map<String, dynamic>? config,
  }) {
    return WorkflowTrigger(
      id: id,
      type: type,
      config: config ?? this.config,
      enabled: enabled ?? this.enabled,
      nextExecution: nextExecution ?? this.nextExecution,
    );
  }
}

/// Workflow execution result
class WorkflowExecutionResult {
  final String workflowId;
  final String executionId;
  final WorkflowStatus status;
  final DateTime startTime;
  final DateTime? endTime;
  final Map<String, dynamic> result;
  final String? errorMessage;
  final Duration? duration;
  final Map<String, dynamic> metrics;

  const WorkflowExecutionResult({
    required this.workflowId,
    required this.executionId,
    required this.status,
    required this.startTime,
    this.endTime,
    this.result = const {},
    this.errorMessage,
    this.duration,
    this.metrics = const {},
  });

  WorkflowExecutionResult copyWith({
    WorkflowStatus? status,
    DateTime? endTime,
    Map<String, dynamic>? result,
    String? errorMessage,
    Duration? duration,
    Map<String, dynamic>? metrics,
  }) {
    return WorkflowExecutionResult(
      workflowId: workflowId,
      executionId: executionId,
      status: status ?? this.status,
      startTime: startTime,
      endTime: endTime ?? this.endTime,
      result: result ?? this.result,
      errorMessage: errorMessage ?? this.errorMessage,
      duration: duration ?? this.duration,
      metrics: metrics ?? this.metrics,
    );
  }
}

/// Abstract workflow task
abstract class WorkflowTask {
  String get id;
  String get description;
  WorkflowPriority get priority;
  Duration get estimatedDuration;
  List<String> get dependencies;

  Future<Map<String, dynamic>> execute(Map<String, dynamic> context);
  Future<bool> canExecute(Map<String, dynamic> context);
  Future<void> cleanup(Map<String, dynamic> context);
}

/// Memory optimization workflow task
class MemoryOptimizationTask implements WorkflowTask {
  final MemoryOptimizer memoryOptimizer;
  final OptimizationConfig? config;

  @override
  final String id;

  @override
  final String description;

  @override
  final WorkflowPriority priority;

  @override
  final Duration estimatedDuration;

  @override
  final List<String> dependencies;

  const MemoryOptimizationTask({
    required this.memoryOptimizer,
    this.config,
    this.id = 'memory_optimization',
    this.description = 'Optimize memory usage through cleanup and archiving',
    this.priority = WorkflowPriority.normal,
    this.estimatedDuration = const Duration(minutes: 5),
    this.dependencies = const [],
  });

  @override
  Future<Map<String, dynamic>> execute(Map<String, dynamic> context) async {
    final result = await memoryOptimizer.optimize();

    return {
      'success': result.success,
      'archivedMessages': result.archivedMessages.length,
      'deletedMessages': result.deletedMessages.length,
      'storageReclaimed': result.storageReclaimed,
      'executionTime': result.executionTime.inMilliseconds,
      'rollbackToken': result.rollbackToken,
    };
  }

  @override
  Future<bool> canExecute(Map<String, dynamic> context) async {
    return await memoryOptimizer.isOptimizationNeeded();
  }

  @override
  Future<void> cleanup(Map<String, dynamic> context) async {
    // No cleanup needed for memory optimization
  }
}

/// Session cleanup workflow task
class SessionCleanupTask implements WorkflowTask {
  final SessionManager sessionManager;
  final Duration? olderThan;
  final List<SessionState>? targetStates;

  @override
  final String id;

  @override
  final String description;

  @override
  final WorkflowPriority priority;

  @override
  final Duration estimatedDuration;

  @override
  final List<String> dependencies;

  const SessionCleanupTask({
    required this.sessionManager,
    this.olderThan,
    this.targetStates,
    this.id = 'session_cleanup',
    this.description = 'Clean up old and inactive sessions',
    this.priority = WorkflowPriority.low,
    this.estimatedDuration = const Duration(minutes: 2),
    this.dependencies = const [],
  });

  @override
  Future<Map<String, dynamic>> execute(Map<String, dynamic> context) async {
    final cleanedCount = await sessionManager.cleanupSessions(
      olderThan: olderThan,
      states: targetStates,
    );

    return {
      'cleanedSessions': cleanedCount,
      'olderThan': olderThan?.inDays,
      'targetStates': targetStates?.map((s) => s.toString()).toList(),
    };
  }

  @override
  Future<bool> canExecute(Map<String, dynamic> context) async {
    // Always can execute session cleanup
    return true;
  }

  @override
  Future<void> cleanup(Map<String, dynamic> context) async {
    // No cleanup needed
  }
}

/// Retention policy evaluation task
class RetentionPolicyTask implements WorkflowTask {
  final PolicyEvaluator policyEvaluator;
  final bool dryRun;

  @override
  final String id;

  @override
  final String description;

  @override
  final WorkflowPriority priority;

  @override
  final Duration estimatedDuration;

  @override
  final List<String> dependencies;

  const RetentionPolicyTask({
    required this.policyEvaluator,
    this.dryRun = true,
    this.id = 'retention_policy_evaluation',
    this.description = 'Evaluate retention policies for messages and sessions',
    this.priority = WorkflowPriority.normal,
    this.estimatedDuration = const Duration(minutes: 3),
    this.dependencies = const [],
  });

  @override
  Future<Map<String, dynamic>> execute(Map<String, dynamic> context) async {
    final messages = context['messages'] as List<Message>? ?? [];
    final result = await policyEvaluator.evaluateMessages(messages);

    return {
      'dryRun': dryRun,
      'totalEvaluated': result.totalEvaluated,
      'toRetain': result.toRetain.length,
      'toArchive': result.toArchive.length,
      'toDelete': result.toDelete.length,
      'toCompress': result.toCompress.length,
      'metrics': result.metrics,
    };
  }

  @override
  Future<bool> canExecute(Map<String, dynamic> context) async {
    final messages = context['messages'] as List<Message>? ?? [];
    return messages.isNotEmpty;
  }

  @override
  Future<void> cleanup(Map<String, dynamic> context) async {
    // No cleanup needed
  }
}

/// Workflow definition
class WorkflowDefinition {
  final String id;
  final String name;
  final String description;
  final List<WorkflowTask> tasks;
  final List<WorkflowTrigger> triggers;
  final WorkflowPriority priority;
  final Duration timeout;
  final int maxRetries;
  final Map<String, dynamic> defaultContext;
  final bool enabled;

  const WorkflowDefinition({
    required this.id,
    required this.name,
    required this.description,
    required this.tasks,
    this.triggers = const [],
    this.priority = WorkflowPriority.normal,
    this.timeout = const Duration(minutes: 30),
    this.maxRetries = 3,
    this.defaultContext = const {},
    this.enabled = true,
  });

  WorkflowDefinition copyWith({
    String? name,
    String? description,
    List<WorkflowTask>? tasks,
    List<WorkflowTrigger>? triggers,
    WorkflowPriority? priority,
    Duration? timeout,
    int? maxRetries,
    Map<String, dynamic>? defaultContext,
    bool? enabled,
  }) {
    return WorkflowDefinition(
      id: id,
      name: name ?? this.name,
      description: description ?? this.description,
      tasks: tasks ?? this.tasks,
      triggers: triggers ?? this.triggers,
      priority: priority ?? this.priority,
      timeout: timeout ?? this.timeout,
      maxRetries: maxRetries ?? this.maxRetries,
      defaultContext: defaultContext ?? this.defaultContext,
      enabled: enabled ?? this.enabled,
    );
  }
}

/// Comprehensive workflow scheduler for automated memory management
class WorkflowScheduler {
  final Logger _logger;

  /// Registered workflows
  final Map<String, WorkflowDefinition> _workflows = {};

  /// Active executions
  final Map<String, WorkflowExecutionResult> _activeExecutions = {};

  /// Execution history
  final List<WorkflowExecutionResult> _executionHistory = [];

  /// Trigger timers
  final Map<String, Timer> _triggerTimers = {};

  /// Event listeners
  final Map<String, List<Function(Map<String, dynamic>)>> _eventListeners = {};

  /// Scheduler state
  bool _isRunning = false;
  Timer? _mainSchedulerTimer;

  WorkflowScheduler({Logger? logger})
    : _logger = logger ?? ChatMemoryLogger.loggerFor('WorkflowScheduler');

  /// Start the workflow scheduler
  Future<void> start() async {
    if (_isRunning) return;

    _isRunning = true;
    _logger.info('Starting WorkflowScheduler');

    // Start main scheduler loop
    _mainSchedulerTimer = Timer.periodic(
      const Duration(minutes: 1),
      (_) => _checkTriggers(),
    );

    // Initialize triggers
    await _initializeTriggers();
  }

  /// Stop the workflow scheduler
  Future<void> stop() async {
    if (!_isRunning) return;

    _isRunning = false;
    _logger.info('Stopping WorkflowScheduler');

    // Cancel main timer
    _mainSchedulerTimer?.cancel();
    _mainSchedulerTimer = null;

    // Cancel all trigger timers
    for (final timer in _triggerTimers.values) {
      timer.cancel();
    }
    _triggerTimers.clear();

    // Cancel active executions
    for (final execution in _activeExecutions.values) {
      if (execution.status == WorkflowStatus.running) {
        await _updateExecution(
          execution.executionId,
          execution.copyWith(
            status: WorkflowStatus.cancelled,
            endTime: DateTime.now(),
          ),
        );
      }
    }
  }

  /// Register a workflow definition
  void registerWorkflow(WorkflowDefinition workflow) {
    _workflows[workflow.id] = workflow;
    _logger.info('Registered workflow: ${workflow.id}');

    // Set up triggers
    for (final trigger in workflow.triggers) {
      _setupTrigger(workflow.id, trigger);
    }
  }

  /// Unregister a workflow
  void unregisterWorkflow(String workflowId) {
    final workflow = _workflows.remove(workflowId);
    if (workflow != null) {
      // Remove triggers
      for (final trigger in workflow.triggers) {
        _removeTrigger(trigger.id);
      }
      _logger.info('Unregistered workflow: $workflowId');
    }
  }

  /// Execute a workflow manually
  Future<WorkflowExecutionResult> executeWorkflow(
    String workflowId, {
    Map<String, dynamic>? context,
  }) async {
    final workflow = _workflows[workflowId];
    if (workflow == null) {
      throw ChatMemoryException(
        'Workflow not found: $workflowId',
        context: ErrorContext(
          operation: 'executeWorkflow',
          component: 'WorkflowScheduler',
          params: {'workflowId': workflowId},
        ),
      );
    }

    if (!workflow.enabled) {
      throw ChatMemoryException(
        'Workflow is disabled: $workflowId',
        context: ErrorContext(
          operation: 'executeWorkflow',
          component: 'WorkflowScheduler',
          params: {'workflowId': workflowId},
        ),
      );
    }

    final executionId = _generateExecutionId();
    final execution = WorkflowExecutionResult(
      workflowId: workflowId,
      executionId: executionId,
      status: WorkflowStatus.pending,
      startTime: DateTime.now(),
    );

    _activeExecutions[executionId] = execution;
    _logger.info('Starting workflow execution: $workflowId ($executionId)');

    try {
      final updatedExecution = execution.copyWith(
        status: WorkflowStatus.running,
      );
      final startTime = DateTime.now();
      final executionWithStartTime = WorkflowExecutionResult(
        workflowId: updatedExecution.workflowId,
        executionId: updatedExecution.executionId,
        status: updatedExecution.status,
        startTime: startTime,
        endTime: updatedExecution.endTime,
        result: updatedExecution.result,
        errorMessage: updatedExecution.errorMessage,
        duration: updatedExecution.duration,
        metrics: updatedExecution.metrics,
      );
      await _updateExecution(executionId, executionWithStartTime);

      final result = await _executeWorkflowTasks(workflow, {
        ...workflow.defaultContext,
        ...?context,
      });

      final completedExecution = executionWithStartTime.copyWith(
        status: WorkflowStatus.completed,
        endTime: DateTime.now(),
        result: result,
        duration: DateTime.now().difference(executionWithStartTime.startTime),
      );

      await _updateExecution(executionId, completedExecution);
      return completedExecution;
    } catch (e, stackTrace) {
      final failedExecution = execution.copyWith(
        status: WorkflowStatus.failed,
        endTime: DateTime.now(),
        errorMessage: e.toString(),
        duration: DateTime.now().difference(execution.startTime),
      );

      await _updateExecution(executionId, failedExecution);

      ChatMemoryLogger.logError(
        _logger,
        'executeWorkflow',
        e,
        stackTrace: stackTrace,
        params: {'workflowId': workflowId, 'executionId': executionId},
      );

      return failedExecution;
    }
  }

  /// Get execution status
  WorkflowExecutionResult? getExecution(String executionId) {
    return _activeExecutions[executionId] ??
        _executionHistory
            .where((e) => e.executionId == executionId)
            .firstOrNull;
  }

  /// Get active executions
  List<WorkflowExecutionResult> getActiveExecutions() {
    return _activeExecutions.values.toList();
  }

  /// Get execution history
  List<WorkflowExecutionResult> getExecutionHistory({
    String? workflowId,
    int? limit,
  }) {
    var history = _executionHistory.toList();

    if (workflowId != null) {
      history = history.where((e) => e.workflowId == workflowId).toList();
    }

    history.sort((a, b) => b.startTime.compareTo(a.startTime));

    if (limit != null && limit > 0) {
      history = history.take(limit).toList();
    }

    return history;
  }

  /// Cancel an active execution
  Future<bool> cancelExecution(String executionId) async {
    final execution = _activeExecutions[executionId];
    if (execution == null || execution.status != WorkflowStatus.running) {
      return false;
    }

    final cancelledExecution = execution.copyWith(
      status: WorkflowStatus.cancelled,
      endTime: DateTime.now(),
      duration: DateTime.now().difference(execution.startTime),
    );

    await _updateExecution(executionId, cancelledExecution);
    _logger.info('Cancelled workflow execution: $executionId');
    return true;
  }

  /// Add event listener
  void addEventListener(String event, Function(Map<String, dynamic>) listener) {
    _eventListeners.putIfAbsent(event, () => []).add(listener);
  }

  /// Remove event listener
  void removeEventListener(
    String event,
    Function(Map<String, dynamic>) listener,
  ) {
    _eventListeners[event]?.remove(listener);
  }

  /// Trigger an event
  void triggerEvent(String event, Map<String, dynamic> data) {
    final listeners = _eventListeners[event];
    if (listeners != null) {
      for (final listener in listeners) {
        try {
          listener(data);
        } catch (e) {
          _logger.warning('Event listener failed for $event: $e');
        }
      }
    }
  }

  /// Execute workflow tasks
  Future<Map<String, dynamic>> _executeWorkflowTasks(
    WorkflowDefinition workflow,
    Map<String, dynamic> context,
  ) async {
    final results = <String, dynamic>{};
    final taskResults = <String, Map<String, dynamic>>{};

    // Sort tasks by dependencies and priority
    final sortedTasks = _sortTasksByDependencies(workflow.tasks);

    for (final task in sortedTasks) {
      try {
        _logger.fine('Executing task: ${task.id}');

        // Check if task can execute
        final canExecute = await task.canExecute({...context, ...taskResults});
        if (!canExecute) {
          _logger.info('Skipping task ${task.id}: cannot execute');
          continue;
        }

        // Execute task
        final stopwatch = Stopwatch()..start();
        final taskResult = await task.execute({...context, ...taskResults});
        stopwatch.stop();

        taskResults[task.id] = {
          ...taskResult,
          'executionTime': stopwatch.elapsed.inMilliseconds,
          'status': 'completed',
        };

        _logger.fine(
          'Completed task ${task.id} in ${stopwatch.elapsed.inMilliseconds}ms',
        );
      } catch (e, stackTrace) {
        _logger.severe('Task ${task.id} failed: $e');

        taskResults[task.id] = {'status': 'failed', 'error': e.toString()};

        // Try cleanup
        try {
          await task.cleanup({...context, ...taskResults});
        } catch (cleanupError) {
          _logger.warning('Task cleanup failed for ${task.id}: $cleanupError');
        }

        // Continue with other tasks unless this is critical
        if (task.priority == WorkflowPriority.critical) {
          rethrow;
        }
      }
    }

    results['tasks'] = taskResults;
    results['completedTasks'] = taskResults.length;
    results['failedTasks'] = taskResults.values
        .where((r) => r['status'] == 'failed')
        .length;

    return results;
  }

  /// Sort tasks by dependencies
  List<WorkflowTask> _sortTasksByDependencies(List<WorkflowTask> tasks) {
    final sorted = <WorkflowTask>[];
    final remaining = tasks.toList();
    final completed = <String>{};

    while (remaining.isNotEmpty) {
      var added = false;

      for (int i = 0; i < remaining.length; i++) {
        final task = remaining[i];
        final canAdd = task.dependencies.every(completed.contains);

        if (canAdd) {
          sorted.add(task);
          completed.add(task.id);
          remaining.removeAt(i);
          added = true;
          break;
        }
      }

      if (!added) {
        // Circular dependency or missing dependency
        _logger.warning('Circular dependency detected, adding remaining tasks');
        sorted.addAll(remaining);
        break;
      }
    }

    // Sort by priority within dependency order
    return sorted..sort((a, b) => b.priority.value.compareTo(a.priority.value));
  }

  /// Initialize triggers
  Future<void> _initializeTriggers() async {
    for (final workflow in _workflows.values) {
      for (final trigger in workflow.triggers) {
        _setupTrigger(workflow.id, trigger);
      }
    }
  }

  /// Setup a trigger
  void _setupTrigger(String workflowId, WorkflowTrigger trigger) {
    if (!trigger.enabled) return;

    switch (trigger.type) {
      case TriggerType.time:
        _setupTimeTrigger(workflowId, trigger);
        break;
      case TriggerType.threshold:
        _setupThresholdTrigger(workflowId, trigger);
        break;
      case TriggerType.event:
        _setupEventTrigger(workflowId, trigger);
        break;
      case TriggerType.manual:
        // Manual triggers don't need setup
        break;
    }
  }

  /// Setup time-based trigger
  void _setupTimeTrigger(String workflowId, WorkflowTrigger trigger) {
    final intervalMinutes = trigger.config['intervalMinutes'] as int? ?? 60;

    _triggerTimers[trigger.id] = Timer.periodic(
      Duration(minutes: intervalMinutes),
      (_) => _executeTrigger(workflowId, trigger),
    );
  }

  /// Setup threshold-based trigger
  void _setupThresholdTrigger(String workflowId, WorkflowTrigger trigger) {
    // Threshold triggers are checked in the main scheduler loop
  }

  /// Setup event-based trigger
  void _setupEventTrigger(String workflowId, WorkflowTrigger trigger) {
    final eventName = trigger.config['eventName'] as String?;
    if (eventName == null) return;

    addEventListener(eventName, (data) {
      _executeTrigger(workflowId, trigger, data);
    });
  }

  /// Remove a trigger
  void _removeTrigger(String triggerId) {
    _triggerTimers[triggerId]?.cancel();
    _triggerTimers.remove(triggerId);
  }

  /// Execute a trigger
  void _executeTrigger(
    String workflowId,
    WorkflowTrigger trigger, [
    Map<String, dynamic>? eventData,
  ]) async {
    if (!_isRunning) return;

    try {
      await executeWorkflow(workflowId, context: eventData);
    } catch (e) {
      _logger.warning('Trigger execution failed for $workflowId: $e');
    }
  }

  /// Check triggers periodically
  void _checkTriggers() async {
    if (!_isRunning) return;

    for (final workflow in _workflows.values) {
      if (!workflow.enabled) continue;

      for (final trigger in workflow.triggers) {
        if (!trigger.enabled) continue;

        if (trigger.type == TriggerType.threshold) {
          await _checkThresholdTrigger(workflow.id, trigger);
        }
      }
    }
  }

  /// Check threshold trigger
  Future<void> _checkThresholdTrigger(
    String workflowId,
    WorkflowTrigger trigger,
  ) async {
    try {
      final memoryThreshold =
          trigger.config['memoryThreshold'] as double? ?? 0.8;
      final checkInterval = trigger.config['checkIntervalMinutes'] as int? ?? 5;

      // Simple memory check (would be more sophisticated in practice)
      final lastCheck = trigger.config['lastCheck'] as DateTime?;
      final now = DateTime.now();

      if (lastCheck != null &&
          now.difference(lastCheck).inMinutes < checkInterval) {
        return;
      }

      // Update last check time
      final updatedTrigger = trigger.copyWith(
        config: {...trigger.config, 'lastCheck': now},
      );

      // This would normally check actual memory usage
      final shouldTrigger =
          math.Random().nextDouble() > 0.95; // Simulated check

      if (shouldTrigger) {
        _executeTrigger(workflowId, updatedTrigger);
      }
    } catch (e) {
      _logger.warning('Threshold trigger check failed: $e');
    }
  }

  /// Update execution status
  Future<void> _updateExecution(
    String executionId,
    WorkflowExecutionResult execution,
  ) async {
    _activeExecutions[executionId] = execution;

    // Move completed/failed executions to history
    if (execution.status == WorkflowStatus.completed ||
        execution.status == WorkflowStatus.failed ||
        execution.status == WorkflowStatus.cancelled) {
      _activeExecutions.remove(executionId);
      _executionHistory.add(execution);

      // Limit history size
      while (_executionHistory.length > 1000) {
        _executionHistory.removeAt(0);
      }
    }
  }

  /// Generate unique execution ID
  String _generateExecutionId() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final random = math.Random().nextInt(1000000);
    return 'exec_${timestamp}_$random';
  }
}

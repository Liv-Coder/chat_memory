import 'dart:async';
import 'package:logging/logging.dart';

import 'memory_optimizer.dart';
import 'session_manager.dart';
import 'workflow_scheduler.dart';
import '../core/persistence/persistence_strategy.dart';
import '../memory/vector_stores/vector_store.dart';
import '../core/models/message.dart';
import '../core/logging/chat_memory_logger.dart';

/// Memory monitoring metrics
class MemoryMetrics {
  final DateTime timestamp;
  final int totalMessages;
  final int totalSessions;
  final int activeSessionCount;
  final int archivedSessionCount;
  final int memoryUsageBytes;
  final int vectorStoreSize;
  final double memoryUsagePercentage;
  final Duration averageResponseTime;
  final Map<String, dynamic> performanceMetrics;
  final Map<String, dynamic> thresholdStatus;

  const MemoryMetrics({
    required this.timestamp,
    required this.totalMessages,
    required this.totalSessions,
    required this.activeSessionCount,
    required this.archivedSessionCount,
    required this.memoryUsageBytes,
    required this.vectorStoreSize,
    required this.memoryUsagePercentage,
    required this.averageResponseTime,
    required this.performanceMetrics,
    required this.thresholdStatus,
  });

  Map<String, dynamic> toJson() {
    return {
      'timestamp': timestamp.toUtc().toIso8601String(),
      'totalMessages': totalMessages,
      'totalSessions': totalSessions,
      'activeSessionCount': activeSessionCount,
      'archivedSessionCount': archivedSessionCount,
      'memoryUsageBytes': memoryUsageBytes,
      'vectorStoreSize': vectorStoreSize,
      'memoryUsagePercentage': memoryUsagePercentage,
      'averageResponseTime': averageResponseTime.inMilliseconds,
      'performanceMetrics': performanceMetrics,
      'thresholdStatus': thresholdStatus,
    };
  }

  static MemoryMetrics fromJson(Map<String, dynamic> json) {
    return MemoryMetrics(
      timestamp: DateTime.parse(json['timestamp'] as String).toUtc(),
      totalMessages: json['totalMessages'] as int,
      totalSessions: json['totalSessions'] as int,
      activeSessionCount: json['activeSessionCount'] as int,
      archivedSessionCount: json['archivedSessionCount'] as int,
      memoryUsageBytes: json['memoryUsageBytes'] as int,
      vectorStoreSize: json['vectorStoreSize'] as int,
      memoryUsagePercentage: (json['memoryUsagePercentage'] as num).toDouble(),
      averageResponseTime: Duration(
        milliseconds: json['averageResponseTime'] as int,
      ),
      performanceMetrics: (json['performanceMetrics'] as Map)
          .cast<String, dynamic>(),
      thresholdStatus: (json['thresholdStatus'] as Map).cast<String, dynamic>(),
    );
  }
}

/// Threshold configuration
class ThresholdConfig {
  final String id;
  final String description;
  final String metric;
  final double warningThreshold;
  final double criticalThreshold;
  final bool enabled;
  final Duration checkInterval;
  final int consecutiveViolations;

  const ThresholdConfig({
    required this.id,
    required this.description,
    required this.metric,
    required this.warningThreshold,
    required this.criticalThreshold,
    this.enabled = true,
    this.checkInterval = const Duration(minutes: 5),
    this.consecutiveViolations = 3,
  });

  ThresholdConfig copyWith({
    String? description,
    double? warningThreshold,
    double? criticalThreshold,
    bool? enabled,
    Duration? checkInterval,
    int? consecutiveViolations,
  }) {
    return ThresholdConfig(
      id: id,
      description: description ?? this.description,
      metric: metric,
      warningThreshold: warningThreshold ?? this.warningThreshold,
      criticalThreshold: criticalThreshold ?? this.criticalThreshold,
      enabled: enabled ?? this.enabled,
      checkInterval: checkInterval ?? this.checkInterval,
      consecutiveViolations:
          consecutiveViolations ?? this.consecutiveViolations,
    );
  }
}

/// Threshold violation alert
class ThresholdAlert {
  final String thresholdId;
  final String metric;
  final double currentValue;
  final double thresholdValue;
  final String severity; // 'warning' or 'critical'
  final DateTime timestamp;
  final int consecutiveViolations;
  final String message;
  final Map<String, dynamic> context;

  const ThresholdAlert({
    required this.thresholdId,
    required this.metric,
    required this.currentValue,
    required this.thresholdValue,
    required this.severity,
    required this.timestamp,
    required this.consecutiveViolations,
    required this.message,
    this.context = const {},
  });

  Map<String, dynamic> toJson() {
    return {
      'thresholdId': thresholdId,
      'metric': metric,
      'currentValue': currentValue,
      'thresholdValue': thresholdValue,
      'severity': severity,
      'timestamp': timestamp.toUtc().toIso8601String(),
      'consecutiveViolations': consecutiveViolations,
      'message': message,
      'context': context,
    };
  }
}

/// Real-time memory monitor with threshold-based triggers
class MemoryMonitor {
  final PersistenceStrategy _persistenceStrategy;
  final VectorStore _vectorStore;
  final MemoryOptimizer? _memoryOptimizer;
  final SessionManager? _sessionManager;
  final WorkflowScheduler? _workflowScheduler;
  final Logger _logger;

  /// Monitoring configuration
  final Duration _monitoringInterval;
  final int _maxMetricsHistory;

  /// Threshold configurations
  final Map<String, ThresholdConfig> _thresholds = {};

  /// Violation counters for consecutive threshold violations
  final Map<String, int> _violationCounters = {};

  /// Historical metrics
  final List<MemoryMetrics> _metricsHistory = [];

  /// Alert listeners
  final List<Function(ThresholdAlert)> _alertListeners = [];

  /// Monitoring state
  bool _isMonitoring = false;
  Timer? _monitoringTimer;

  /// Performance tracking
  final List<Duration> _recentResponseTimes = [];

  MemoryMonitor({
    required PersistenceStrategy persistenceStrategy,
    required VectorStore vectorStore,
    MemoryOptimizer? memoryOptimizer,
    SessionManager? sessionManager,
    WorkflowScheduler? workflowScheduler,
    Logger? logger,
    Duration monitoringInterval = const Duration(minutes: 1),
    int maxMetricsHistory = 1440, // 24 hours of minute-by-minute data
  }) : _persistenceStrategy = persistenceStrategy,
       _vectorStore = vectorStore,
       _memoryOptimizer = memoryOptimizer,
       _sessionManager = sessionManager,
       _workflowScheduler = workflowScheduler,
       _logger = logger ?? ChatMemoryLogger.loggerFor('MemoryMonitor'),
       _monitoringInterval = monitoringInterval,
       _maxMetricsHistory = maxMetricsHistory {
    _initializeDefaultThresholds();
  }

  /// Start monitoring
  Future<void> startMonitoring() async {
    if (_isMonitoring) return;

    _isMonitoring = true;
    _logger.info(
      'Starting memory monitoring with interval: $_monitoringInterval',
    );

    // Start monitoring timer
    _monitoringTimer = Timer.periodic(
      _monitoringInterval,
      (_) => _collectMetrics(),
    );

    // Initial metrics collection
    await _collectMetrics();
  }

  /// Stop monitoring
  Future<void> stopMonitoring() async {
    if (!_isMonitoring) return;

    _isMonitoring = false;
    _monitoringTimer?.cancel();
    _monitoringTimer = null;

    _logger.info('Stopped memory monitoring');
  }

  /// Get current memory metrics
  Future<MemoryMetrics> getCurrentMetrics() async {
    return await _collectAndAnalyzeMetrics();
  }

  /// Get metrics history
  List<MemoryMetrics> getMetricsHistory({DateTime? since, int? limit}) {
    var history = _metricsHistory.toList();

    if (since != null) {
      history = history.where((m) => m.timestamp.isAfter(since)).toList();
    }

    if (limit != null && limit > 0) {
      history = history.take(limit).toList();
    }

    return history;
  }

  /// Add threshold configuration
  void addThreshold(ThresholdConfig threshold) {
    _thresholds[threshold.id] = threshold;
    _violationCounters[threshold.id] = 0;
    _logger.info('Added threshold: ${threshold.id}');
  }

  /// Remove threshold configuration
  void removeThreshold(String thresholdId) {
    _thresholds.remove(thresholdId);
    _violationCounters.remove(thresholdId);
    _logger.info('Removed threshold: $thresholdId');
  }

  /// Update threshold configuration
  void updateThreshold(String thresholdId, ThresholdConfig threshold) {
    if (_thresholds.containsKey(thresholdId)) {
      _thresholds[thresholdId] = threshold;
      _logger.info('Updated threshold: $thresholdId');
    }
  }

  /// Get threshold configurations
  Map<String, ThresholdConfig> getThresholds() {
    return Map.unmodifiable(_thresholds);
  }

  /// Add alert listener
  void addAlertListener(Function(ThresholdAlert) listener) {
    _alertListeners.add(listener);
  }

  /// Remove alert listener
  void removeAlertListener(Function(ThresholdAlert) listener) {
    _alertListeners.remove(listener);
  }

  /// Record response time for performance tracking
  void recordResponseTime(Duration responseTime) {
    _recentResponseTimes.add(responseTime);

    // Keep only recent response times (last 100)
    while (_recentResponseTimes.length > 100) {
      _recentResponseTimes.removeAt(0);
    }
  }

  /// Get performance statistics
  Map<String, dynamic> getPerformanceStats() {
    if (_recentResponseTimes.isEmpty) {
      return {
        'averageResponseTime': 0,
        'minResponseTime': 0,
        'maxResponseTime': 0,
        'sampleCount': 0,
      };
    }

    final times = _recentResponseTimes.map((d) => d.inMilliseconds).toList();
    times.sort();

    return {
      'averageResponseTime': times.reduce((a, b) => a + b) / times.length,
      'minResponseTime': times.first,
      'maxResponseTime': times.last,
      'medianResponseTime': times[times.length ~/ 2],
      'p95ResponseTime': times[(times.length * 0.95).floor()],
      'sampleCount': times.length,
    };
  }

  /// Collect and analyze metrics
  Future<MemoryMetrics> _collectAndAnalyzeMetrics() async {
    try {
      final stopwatch = Stopwatch()..start();

      // Collect basic metrics
      final messages = await _persistenceStrategy.loadMessages();
      final vectorStoreSize = await _vectorStore.count();

      // Session metrics
      int activeSessions = 0;
      int archivedSessions = 0;
      int totalSessions = 0;

      if (_sessionManager != null) {
        final activeSessionsList = await _sessionManager.getActiveSessions();
        activeSessions = activeSessionsList.length;

        final allSessions = await _sessionManager.searchSessions();
        totalSessions = allSessions.length;
        archivedSessions = allSessions
            .where((s) => s.state == SessionState.archived)
            .length;
      }

      // Memory usage calculation
      final memoryUsageBytes = _calculateMemoryUsage(messages);
      final memoryUsagePercentage = _memoryOptimizer != null
          ? (await _memoryOptimizer.getMemoryUsage()).memoryUsagePercentage
          : 0.0;

      // Performance metrics
      final performanceStats = getPerformanceStats();
      final averageResponseTime = Duration(
        milliseconds: (performanceStats['averageResponseTime'] as num).round(),
      );

      stopwatch.stop();

      final metrics = MemoryMetrics(
        timestamp: DateTime.now(),
        totalMessages: messages.length,
        totalSessions: totalSessions,
        activeSessionCount: activeSessions,
        archivedSessionCount: archivedSessions,
        memoryUsageBytes: memoryUsageBytes,
        vectorStoreSize: vectorStoreSize,
        memoryUsagePercentage: memoryUsagePercentage,
        averageResponseTime: averageResponseTime,
        performanceMetrics: performanceStats,
        thresholdStatus: _evaluateThresholds(
          memoryUsagePercentage,
          performanceStats,
        ),
      );

      return metrics;
    } catch (e, stackTrace) {
      ChatMemoryLogger.logError(
        _logger,
        '_collectAndAnalyzeMetrics',
        e,
        stackTrace: stackTrace,
      );

      // Return default metrics on error
      return MemoryMetrics(
        timestamp: DateTime.now(),
        totalMessages: 0,
        totalSessions: 0,
        activeSessionCount: 0,
        archivedSessionCount: 0,
        memoryUsageBytes: 0,
        vectorStoreSize: 0,
        memoryUsagePercentage: 0.0,
        averageResponseTime: Duration.zero,
        performanceMetrics: {},
        thresholdStatus: {},
      );
    }
  }

  /// Collect metrics periodically
  Future<void> _collectMetrics() async {
    if (!_isMonitoring) return;

    try {
      final metrics = await _collectAndAnalyzeMetrics();

      // Add to history
      _metricsHistory.add(metrics);

      // Trim history to max size
      while (_metricsHistory.length > _maxMetricsHistory) {
        _metricsHistory.removeAt(0);
      }

      // Check thresholds and generate alerts
      _checkThresholds(metrics);

      _logger.fine(
        'Collected metrics: ${metrics.totalMessages} messages, '
        '${metrics.memoryUsagePercentage.toStringAsFixed(1)}% memory usage',
      );
    } catch (e, stackTrace) {
      ChatMemoryLogger.logError(
        _logger,
        '_collectMetrics',
        e,
        stackTrace: stackTrace,
      );
    }
  }

  /// Calculate memory usage for messages
  int _calculateMemoryUsage(List<Message> messages) {
    return messages.fold(0, (total, message) {
      return total +
          message.content.length * 2 + // UTF-16 encoding
          message.id.length * 2 +
          message.role.toString().length * 2 +
          100; // Overhead for object structure
    });
  }

  /// Evaluate thresholds against current metrics
  Map<String, dynamic> _evaluateThresholds(
    double memoryUsagePercentage,
    Map<String, dynamic> performanceStats,
  ) {
    final thresholdStatus = <String, dynamic>{};

    for (final threshold in _thresholds.values) {
      if (!threshold.enabled) continue;

      double? currentValue;

      switch (threshold.metric) {
        case 'memoryUsagePercentage':
          currentValue = memoryUsagePercentage;
          break;
        case 'averageResponseTime':
          currentValue = performanceStats['averageResponseTime'] as double?;
          break;
        case 'p95ResponseTime':
          currentValue = performanceStats['p95ResponseTime'] as double?;
          break;
      }

      if (currentValue != null) {
        final isWarning = currentValue >= threshold.warningThreshold;
        final isCritical = currentValue >= threshold.criticalThreshold;

        thresholdStatus[threshold.id] = {
          'currentValue': currentValue,
          'warningThreshold': threshold.warningThreshold,
          'criticalThreshold': threshold.criticalThreshold,
          'isWarning': isWarning,
          'isCritical': isCritical,
          'status': isCritical
              ? 'critical'
              : (isWarning ? 'warning' : 'normal'),
        };
      }
    }

    return thresholdStatus;
  }

  /// Check thresholds and generate alerts
  void _checkThresholds(MemoryMetrics metrics) {
    for (final threshold in _thresholds.values) {
      if (!threshold.enabled) continue;

      final status =
          metrics.thresholdStatus[threshold.id] as Map<String, dynamic>?;
      if (status == null) continue;

      final currentValue = status['currentValue'] as double;
      final isWarning = status['isWarning'] as bool;
      final isCritical = status['isCritical'] as bool;

      if (isWarning || isCritical) {
        _violationCounters[threshold.id] =
            (_violationCounters[threshold.id] ?? 0) + 1;

        // Check if we've reached consecutive violation threshold
        if (_violationCounters[threshold.id]! >=
            threshold.consecutiveViolations) {
          final severity = isCritical ? 'critical' : 'warning';
          final thresholdValue = isCritical
              ? threshold.criticalThreshold
              : threshold.warningThreshold;

          final alert = ThresholdAlert(
            thresholdId: threshold.id,
            metric: threshold.metric,
            currentValue: currentValue,
            thresholdValue: thresholdValue,
            severity: severity,
            timestamp: metrics.timestamp,
            consecutiveViolations: _violationCounters[threshold.id]!,
            message:
                '${threshold.description}: ${threshold.metric} is $currentValue '
                '(threshold: $thresholdValue)',
            context: {
              'metrics': metrics.toJson(),
              'threshold': {
                'id': threshold.id,
                'description': threshold.description,
                'metric': threshold.metric,
              },
            },
          );

          _notifyAlert(alert);

          // Trigger workflow if configured
          _triggerWorkflow(alert);
        }
      } else {
        // Reset violation counter when threshold is not violated
        _violationCounters[threshold.id] = 0;
      }
    }
  }

  /// Notify alert listeners
  void _notifyAlert(ThresholdAlert alert) {
    _logger.warning(
      'Threshold alert: ${alert.message} '
      '(${alert.consecutiveViolations} consecutive violations)',
    );

    for (final listener in _alertListeners) {
      try {
        listener(alert);
      } catch (e) {
        _logger.warning('Alert listener failed: $e');
      }
    }
  }

  /// Trigger workflow based on alert
  void _triggerWorkflow(ThresholdAlert alert) {
    if (_workflowScheduler == null) return;

    try {
      final eventData = {
        'alert': alert.toJson(),
        'triggerType': 'threshold_violation',
        'severity': alert.severity,
        'metric': alert.metric,
      };

      _workflowScheduler.triggerEvent('threshold_alert', eventData);
    } catch (e) {
      _logger.warning('Failed to trigger workflow for alert: $e');
    }
  }

  /// Initialize default threshold configurations
  void _initializeDefaultThresholds() {
    addThreshold(
      const ThresholdConfig(
        id: 'memory_usage_warning',
        description: 'Memory usage warning threshold',
        metric: 'memoryUsagePercentage',
        warningThreshold: 0.8,
        criticalThreshold: 0.95,
        checkInterval: Duration(minutes: 1),
        consecutiveViolations: 3,
      ),
    );

    addThreshold(
      const ThresholdConfig(
        id: 'response_time_warning',
        description: 'Average response time warning threshold',
        metric: 'averageResponseTime',
        warningThreshold: 1000.0, // 1 second
        criticalThreshold: 5000.0, // 5 seconds
        checkInterval: Duration(minutes: 2),
        consecutiveViolations: 2,
      ),
    );

    addThreshold(
      const ThresholdConfig(
        id: 'p95_response_time_warning',
        description: '95th percentile response time warning threshold',
        metric: 'p95ResponseTime',
        warningThreshold: 2000.0, // 2 seconds
        criticalThreshold: 10000.0, // 10 seconds
        checkInterval: Duration(minutes: 5),
        consecutiveViolations: 2,
      ),
    );
  }
}

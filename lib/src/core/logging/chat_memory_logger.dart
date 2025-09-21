// Centralized logging configuration and helpers for the chat_memory library.
//
// Uses `package:logging` to provide structured logging, environment-driven
// configuration, and convenience helpers for operation and error logging.

import 'dart:io';

import 'package:logging/logging.dart';

class ChatMemoryLogger {
  static const _rootName = 'chat_memory';
  static final Logger _root = Logger(_rootName);

  /// Performance threshold; operations slower than this will be logged at WARNING.
  static Duration? _performanceThreshold;

  /// Whether the logger has been configured.
  static bool _configured = false;

  /// Configure programmatically with a [Level] and optional [onRecord] handler.
  /// If not called, configureFromEnvironment() will be used on first use.
  static void configure(Level level, {void Function(LogRecord)? onRecord}) {
    if (_configured) return;
    hierarchicalLoggingEnabled = true;
    Logger.root.level = level;
    if (onRecord != null) {
      Logger.root.onRecord.listen(onRecord);
    } else {
      Logger.root.onRecord.listen(_defaultHandler);
    }
    _configured = true;
    _root.fine('ChatMemoryLogger configured programmatically at level: $level');
  }

  /// Configure logger using environment variable `CHAT_MEMORY_LOG_LEVEL`.
  /// Falls back to [Level.WARNING] if variable is missing or invalid.
  static void configureFromEnvironment() {
    if (_configured) return;
    final raw = _readEnv('CHAT_MEMORY_LOG_LEVEL');
    final level = _parseLevel(raw) ?? Level.WARNING;
    configure(level);
    _root.info('ChatMemoryLogger configured from environment at level: $level');
  }

  /// Parse level names like "INFO", "FINE", "SEVERE".
  static Level? _parseLevel(String? raw) {
    if (raw == null) return null;
    switch (raw.toUpperCase()) {
      case 'ALL':
        return Level.ALL;
      case 'FINEST':
        return Level.FINEST;
      case 'FINER':
        return Level.FINER;
      case 'FINE':
        return Level.FINE;
      case 'CONFIG':
        return Level.CONFIG;
      case 'INFO':
        return Level.INFO;
      case 'WARNING':
      case 'WARN':
        return Level.WARNING;
      case 'SEVERE':
        return Level.SEVERE;
      case 'SHOUT':
        return Level.SHOUT;
      case 'OFF':
        return Level.OFF;
      default:
        return null;
    }
  }

  static String? _readEnv(String key) {
    try {
      return Platform.environment[key];
    } catch (_) {
      return null;
    }
  }

  static void _defaultHandler(LogRecord record) {
    final ts = record.time.toIso8601String();
    final logger = record.loggerName;
    final level = record.level.name;
    final message = record.message;
    final error = record.error;
    final stack = record.stackTrace;
    final buffer = StringBuffer();
    buffer.write('[$ts] [$logger] [$level] $message');
    if (error != null) buffer.write(' error: $error');
    if (stack != null) buffer.write('\n$stack');
    // Print to stdout to ensure visibility in typical runtimes.
    stdout.writeln(buffer.toString());
  }

  /// Get a library-scoped logger for a component.
  static Logger loggerFor(String component) {
    configureFromEnvironment();
    return Logger('$_rootName.$component');
  }

  /// Log operation start with optional params. Returns a stopwatch token to
  /// be passed to logOperationEnd for performance measurement.
  static Stopwatch logOperationStart(
    Logger logger,
    String operation, {
    Map<String, Object?>? params,
  }) {
    logger.fine('START $operation ${params ?? {}}');
    final sw = Stopwatch();
    sw.start();
    return sw;
  }

  /// Log operation end and optionally emit a performance warning if the
  /// duration exceeds the configured performance threshold.
  static void logOperationEnd(
    Logger logger,
    String operation,
    Stopwatch sw, {
    Map<String, Object?>? result,
  }) {
    sw.stop();
    final elapsed = sw.elapsed;
    logger.fine(
      'END $operation duration=${elapsed.inMilliseconds}ms result=${result ?? {}}',
    );
    if (_performanceThreshold != null && elapsed > _performanceThreshold!) {
      logger.warning(
        'SLOW_OPERATION $operation duration=${elapsed.inMilliseconds}ms exceeds threshold ${_performanceThreshold!.inMilliseconds}ms',
      );
    }
  }

  /// Log an error with optional context and rethrow if [rethrow] is true.
  static T? logError<T>(
    Logger logger,
    String operation,
    Object error, {
    StackTrace? stackTrace,
    Map<String, Object?>? params,
    bool shouldRethrow = false,
  }) {
    final context = params ?? <String, Object?>{};
    logger.severe('ERROR $operation context=$context', error, stackTrace);
    if (shouldRethrow) {
      if (error is Error) {
        // preserve stack trace if available
        throw error;
      } else if (error is Exception) {
        throw error;
      } else {
        throw StateError('Non-exception thrown: $error');
      }
    }
    // Do not throw when shouldRethrow is false; return null to indicate
    // the error has been logged and caller should continue with graceful degradation.
    return null;
  }

  /// Enable performance logging for operations slower than [threshold].
  static void enablePerformanceLogging(Duration threshold) {
    _performanceThreshold = threshold;
    loggerFor('logger').info(
      'Performance logging enabled threshold=${threshold.inMilliseconds}ms',
    );
  }
}

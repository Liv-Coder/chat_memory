// lib/src/errors.dart
// Centralized exception types, contexts, and validation utilities for chat_memory.
//
// These are lightweight, immutable exception classes intended to carry
// a message, optional cause, and stack trace. They provide consistent
// toString() output that includes cause chains for easier logging.

import 'package:meta/meta.dart';

/// Captures operation context for richer error messages and structured logging.
@immutable
class ErrorContext {
  final String component;
  final String operation;
  final Map<String, Object?>? params;

  const ErrorContext({
    required this.component,
    required this.operation,
    this.params,
  });

  @override
  String toString() {
    final p = params;
    if (p == null || p.isEmpty) {
      return '$component::$operation';
    }
    return '$component::$operation $p';
  }

  Map<String, Object?> toMap() => {
    'component': component,
    'operation': operation,
    'params': params,
  };
}

/// Base class for all library-specific exceptions.
/// Keeps message, optional cause, and optional stack trace for logging.
class ChatMemoryException implements Exception {
  final String message;
  final Object? cause;
  final StackTrace? stackTrace;
  final ErrorContext? context;

  const ChatMemoryException(
    this.message, {
    this.cause,
    this.stackTrace,
    this.context,
  });

  @override
  String toString() {
    final buffer = StringBuffer()..write('ChatMemoryException: $message');
    if (context != null) buffer.write(' ($context)');
    if (cause != null) buffer.write('\n  cause: $cause');
    if (stackTrace != null) buffer.write('\n  stackTrace: $stackTrace');
    return buffer.toString();
  }
}

/// General memory management failures.
class MemoryException extends ChatMemoryException {
  const MemoryException(
    super.message, {
    super.cause,
    super.stackTrace,
    super.context,
  });

  factory MemoryException.fromMessage(
    String message, {
    ErrorContext? context,
  }) => MemoryException(message, context: context);
}

/// Vector store related failures (storage, retrieval, consistency).
class VectorStoreException extends ChatMemoryException {
  const VectorStoreException(
    super.message, {
    super.cause,
    super.stackTrace,
    super.context,
  });

  factory VectorStoreException.dimensionMismatch({
    required int expected,
    required int actual,
    ErrorContext? context,
  }) => VectorStoreException(
    'Vector dimension mismatch: expected=$expected actual=$actual',
    context: context,
  );

  factory VectorStoreException.storageFailure(
    String reason, {
    Object? cause,
    ErrorContext? context,
    StackTrace? stackTrace,
  }) => VectorStoreException(
    'Storage failure: $reason',
    cause: cause,
    stackTrace: stackTrace,
    context: context,
  );
}

/// Configuration and parameter validation failures.
class ConfigurationException extends ChatMemoryException {
  const ConfigurationException(
    super.message, {
    super.cause,
    super.stackTrace,
    super.context,
  });

  factory ConfigurationException.missing(
    String paramName, {
    ErrorContext? context,
  }) => ConfigurationException(
    'Missing required configuration: $paramName',
    context: context,
  );

  factory ConfigurationException.invalid(
    String paramName,
    String reason, {
    ErrorContext? context,
  }) => ConfigurationException(
    'Invalid configuration - $paramName: $reason',
    context: context,
  );
}

/// Summarization related failures.
class SummarizationException extends ChatMemoryException {
  const SummarizationException(
    super.message, {
    super.cause,
    super.stackTrace,
    super.context,
  });

  factory SummarizationException.partialFailure(
    String message, {
    ErrorContext? context,
  }) => SummarizationException(message, context: context);
}

/// Utilities for common validation patterns used across the library.
///
/// These utilities avoid throwing raw [Exception] and instead throw
/// [ConfigurationException] when validations fail so callers can catch
/// and handle them consistently.
class Validation {
  static void validatePositive(
    String name,
    num value, {
    ErrorContext? context,
  }) {
    if (value <= 0) {
      throw ConfigurationException.invalid(
        name,
        'must be > 0',
        context: context,
      );
    }
  }

  static void validateNonNegative(
    String name,
    num value, {
    ErrorContext? context,
  }) {
    if (value < 0) {
      throw ConfigurationException.invalid(
        name,
        'must be >= 0',
        context: context,
      );
    }
  }

  static void validateRange(
    String name,
    num value, {
    required num min,
    required num max,
    ErrorContext? context,
  }) {
    if (value < min || value > max) {
      throw ConfigurationException.invalid(
        name,
        'must be between $min and $max',
        context: context,
      );
    }
  }

  static void validateNonEmptyString(
    String name,
    String? value, {
    ErrorContext? context,
  }) {
    if (value == null || value.trim().isEmpty) {
      throw ConfigurationException.invalid(
        name,
        'must be a non-empty string',
        context: context,
      );
    }
  }

  static void validateListNotEmpty<T>(
    String name,
    List<T>? list, {
    ErrorContext? context,
  }) {
    if (list == null || list.isEmpty) {
      throw ConfigurationException.invalid(
        name,
        'must be a non-empty list',
        context: context,
      );
    }
  }

  static void validateEmbeddingVector(
    String name,
    List<double>? vector, {
    int? expectedDim,
    ErrorContext? context,
  }) {
    if (vector == null || vector.isEmpty) {
      throw VectorStoreException(
        'Embedding vector "$name" is null or empty',
        context: context,
      );
    }
    if (vector.any((v) => v.isNaN || v.isInfinite)) {
      throw VectorStoreException(
        'Embedding vector "$name" contains NaN or infinite values',
        context: context,
      );
    }
    if (expectedDim != null && vector.length != expectedDim) {
      throw VectorStoreException.dimensionMismatch(
        expected: expectedDim,
        actual: vector.length,
        context: context,
      );
    }
  }
}

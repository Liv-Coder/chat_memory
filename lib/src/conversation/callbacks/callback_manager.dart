import '../../core/errors.dart';
import '../../core/logging/chat_memory_logger.dart';
import '../../core/models/message.dart';

/// Callback function type for message storage events
typedef MessageStoredCallback = void Function(Message message);

/// Callback function type for summary creation events
typedef SummaryCreatedCallback = void Function(Message summary);

/// Manages callback execution with failure tracking and automatic disabling
///
/// This class provides robust callback management with failure counting,
/// automatic disabling after threshold breaches, and comprehensive logging
/// for conversation management components.
class CallbackManager {
  final _logger = ChatMemoryLogger.loggerFor('callbacks.manager');

  // Callback storage
  MessageStoredCallback? _onMessageStored;
  SummaryCreatedCallback? _onSummaryCreated;

  // Failure tracking
  int _messageStoredFailures = 0;
  int _summaryCreatedFailures = 0;
  bool _messageStoredDisabled = false;
  bool _summaryCreatedDisabled = false;

  // Configuration
  final int _failureThreshold;

  CallbackManager({
    MessageStoredCallback? onMessageStored,
    SummaryCreatedCallback? onSummaryCreated,
    int failureThreshold = 3,
  }) : _onMessageStored = onMessageStored,
       _onSummaryCreated = onSummaryCreated,
       _failureThreshold = failureThreshold {
    _logger.fine('CallbackManager initialized', {
      'hasMessageStoredCallback': _onMessageStored != null,
      'hasSummaryCreatedCallback': _onSummaryCreated != null,
      'failureThreshold': _failureThreshold,
    });
  }

  /// Register a callback for message storage events
  void registerMessageStoredCallback(MessageStoredCallback? callback) {
    _onMessageStored = callback;
    if (!_messageStoredDisabled) {
      _messageStoredFailures =
          0; // Reset failures when new callback is registered
    }
    _logger.fine('Message stored callback registered', {
      'hasCallback': callback != null,
      'wasDisabled': _messageStoredDisabled,
    });
  }

  /// Register a callback for summary creation events
  void registerSummaryCreatedCallback(SummaryCreatedCallback? callback) {
    _onSummaryCreated = callback;
    if (!_summaryCreatedDisabled) {
      _summaryCreatedFailures =
          0; // Reset failures when new callback is registered
    }
    _logger.fine('Summary created callback registered', {
      'hasCallback': callback != null,
      'wasDisabled': _summaryCreatedDisabled,
    });
  }

  /// Execute the message stored callback with failure tracking
  Future<void> executeMessageStoredCallback(Message message) async {
    if (_onMessageStored == null || _messageStoredDisabled) {
      return;
    }

    final opCtx = ErrorContext(
      component: 'CallbackManager',
      operation: 'executeMessageStoredCallback',
      params: {'messageId': message.id, 'role': message.role.toString()},
    );

    try {
      _onMessageStored!(message);
      _logger.fine(
        'Message stored callback executed successfully',
        opCtx.toMap(),
      );
    } catch (e, st) {
      _messageStoredFailures++;

      ChatMemoryLogger.logError(
        _logger,
        'executeMessageStoredCallback',
        e,
        stackTrace: st,
        params: {
          ...opCtx.toMap(),
          'failureCount': _messageStoredFailures,
          'failureThreshold': _failureThreshold,
        },
        shouldRethrow: false,
      );

      if (_messageStoredFailures >= _failureThreshold) {
        _messageStoredDisabled = true;
        _logger.warning(
          'Message stored callback disabled due to repeated failures',
          {
            ...opCtx.toMap(),
            'failureCount': _messageStoredFailures,
            'threshold': _failureThreshold,
          },
        );
      }
    }
  }

  /// Execute the summary created callback with failure tracking
  Future<void> executeSummaryCreatedCallback(Message summary) async {
    if (_onSummaryCreated == null || _summaryCreatedDisabled) {
      return;
    }

    final opCtx = ErrorContext(
      component: 'CallbackManager',
      operation: 'executeSummaryCreatedCallback',
      params: {
        'summaryId': summary.id,
        'contentLength': summary.content.length,
      },
    );

    try {
      _onSummaryCreated!(summary);
      _logger.fine(
        'Summary created callback executed successfully',
        opCtx.toMap(),
      );
    } catch (e, st) {
      _summaryCreatedFailures++;

      ChatMemoryLogger.logError(
        _logger,
        'executeSummaryCreatedCallback',
        e,
        stackTrace: st,
        params: {
          ...opCtx.toMap(),
          'failureCount': _summaryCreatedFailures,
          'failureThreshold': _failureThreshold,
        },
        shouldRethrow: false,
      );

      if (_summaryCreatedFailures >= _failureThreshold) {
        _summaryCreatedDisabled = true;
        _logger.warning(
          'Summary created callback disabled due to repeated failures',
          {
            ...opCtx.toMap(),
            'failureCount': _summaryCreatedFailures,
            'threshold': _failureThreshold,
          },
        );
      }
    }
  }

  /// Reset callback failure tracking and re-enable disabled callbacks
  void resetCallbacks() {
    _messageStoredFailures = 0;
    _summaryCreatedFailures = 0;
    _messageStoredDisabled = false;
    _summaryCreatedDisabled = false;

    _logger.info('All callbacks reset and re-enabled', {
      'messageStoredFailures': _messageStoredFailures,
      'summaryCreatedFailures': _summaryCreatedFailures,
    });
  }

  /// Reset message stored callback failure tracking
  void resetMessageStoredCallback() {
    _messageStoredFailures = 0;
    _messageStoredDisabled = false;

    _logger.info('Message stored callback reset and re-enabled', {
      'failures': _messageStoredFailures,
    });
  }

  /// Reset summary created callback failure tracking
  void resetSummaryCreatedCallback() {
    _summaryCreatedFailures = 0;
    _summaryCreatedDisabled = false;

    _logger.info('Summary created callback reset and re-enabled', {
      'failures': _summaryCreatedFailures,
    });
  }

  /// Get callback status information
  Map<String, dynamic> getCallbackStatus() {
    return {
      'messageStored': {
        'registered': _onMessageStored != null,
        'enabled': !_messageStoredDisabled,
        'failures': _messageStoredFailures,
        'threshold': _failureThreshold,
      },
      'summaryCreated': {
        'registered': _onSummaryCreated != null,
        'enabled': !_summaryCreatedDisabled,
        'failures': _summaryCreatedFailures,
        'threshold': _failureThreshold,
      },
    };
  }

  /// Check if message stored callback is available and enabled
  bool get isMessageStoredCallbackEnabled =>
      _onMessageStored != null && !_messageStoredDisabled;

  /// Check if summary created callback is available and enabled
  bool get isSummaryCreatedCallbackEnabled =>
      _onSummaryCreated != null && !_summaryCreatedDisabled;

  /// Get total callback failure count
  int get totalFailures => _messageStoredFailures + _summaryCreatedFailures;

  /// Check if any callbacks are disabled
  bool get hasDisabledCallbacks =>
      _messageStoredDisabled || _summaryCreatedDisabled;
}

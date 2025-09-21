import 'dart:async';
import 'dart:convert';
import 'package:logging/logging.dart';

import '../core/persistence/persistence_strategy.dart';
import '../core/models/message.dart';
import '../core/errors.dart';
import '../core/logging/chat_memory_logger.dart';

/// Session state enumeration
enum SessionState { active, suspended, archived, terminated }

/// Session metadata
class SessionMetadata {
  final String sessionId;
  final String title;
  final String? description;
  final Map<String, dynamic> customData;
  final DateTime createdAt;
  final DateTime lastAccessedAt;
  final DateTime? terminatedAt;
  final SessionState state;
  final int messageCount;
  final int totalTokens;
  final List<String> participants;
  final Map<String, dynamic> statistics;

  const SessionMetadata({
    required this.sessionId,
    required this.title,
    this.description,
    required this.customData,
    required this.createdAt,
    required this.lastAccessedAt,
    this.terminatedAt,
    required this.state,
    required this.messageCount,
    required this.totalTokens,
    required this.participants,
    required this.statistics,
  });

  SessionMetadata copyWith({
    String? title,
    String? description,
    Map<String, dynamic>? customData,
    DateTime? lastAccessedAt,
    DateTime? terminatedAt,
    SessionState? state,
    int? messageCount,
    int? totalTokens,
    List<String>? participants,
    Map<String, dynamic>? statistics,
  }) {
    return SessionMetadata(
      sessionId: sessionId,
      title: title ?? this.title,
      description: description ?? this.description,
      customData: customData ?? this.customData,
      createdAt: createdAt,
      lastAccessedAt: lastAccessedAt ?? this.lastAccessedAt,
      terminatedAt: terminatedAt ?? this.terminatedAt,
      state: state ?? this.state,
      messageCount: messageCount ?? this.messageCount,
      totalTokens: totalTokens ?? this.totalTokens,
      participants: participants ?? this.participants,
      statistics: statistics ?? this.statistics,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'sessionId': sessionId,
      'title': title,
      'description': description,
      'customData': customData,
      'createdAt': createdAt.toUtc().toIso8601String(),
      'lastAccessedAt': lastAccessedAt.toUtc().toIso8601String(),
      'terminatedAt': terminatedAt?.toUtc().toIso8601String(),
      'state': state.toString(),
      'messageCount': messageCount,
      'totalTokens': totalTokens,
      'participants': participants,
      'statistics': statistics,
    };
  }

  static SessionMetadata fromJson(Map<String, dynamic> json) {
    return SessionMetadata(
      sessionId: json['sessionId'] as String,
      title: json['title'] as String,
      description: json['description'] as String?,
      customData: (json['customData'] as Map).cast<String, dynamic>(),
      createdAt: DateTime.parse(json['createdAt'] as String).toUtc(),
      lastAccessedAt: DateTime.parse(json['lastAccessedAt'] as String).toUtc(),
      terminatedAt: json['terminatedAt'] != null
          ? DateTime.parse(json['terminatedAt'] as String).toUtc()
          : null,
      state: SessionState.values.firstWhere(
        (e) => e.toString() == json['state'],
      ),
      messageCount: json['messageCount'] as int,
      totalTokens: json['totalTokens'] as int,
      participants: (json['participants'] as List).cast<String>(),
      statistics: (json['statistics'] as Map).cast<String, dynamic>(),
    );
  }
}

/// Session creation configuration
class SessionConfig {
  final String? title;
  final String? description;
  final Map<String, dynamic> customData;
  final List<String> initialParticipants;
  final bool autoArchive;
  final Duration? autoArchiveAfter;
  final int? maxMessages;
  final int? maxTokens;

  const SessionConfig({
    this.title,
    this.description,
    this.customData = const {},
    this.initialParticipants = const [],
    this.autoArchive = false,
    this.autoArchiveAfter,
    this.maxMessages,
    this.maxTokens,
  });
}

/// Session search filter
class SessionFilter {
  final SessionState? state;
  final String? titlePattern;
  final DateTime? createdAfter;
  final DateTime? createdBefore;
  final DateTime? lastAccessedAfter;
  final DateTime? lastAccessedBefore;
  final List<String>? participants;
  final Map<String, dynamic>? customDataFilters;
  final int? minMessageCount;
  final int? maxMessageCount;

  const SessionFilter({
    this.state,
    this.titlePattern,
    this.createdAfter,
    this.createdBefore,
    this.lastAccessedAfter,
    this.lastAccessedBefore,
    this.participants,
    this.customDataFilters,
    this.minMessageCount,
    this.maxMessageCount,
  });
}

/// Comprehensive session lifecycle manager
class SessionManager {
  final PersistenceStrategy _persistenceStrategy;
  final PersistenceStrategy? _archiveStorage;
  final Logger _logger;

  /// Active sessions cache
  final Map<String, SessionMetadata> _activeSessions = {};

  /// Session event listeners
  final Map<String, List<Function(SessionMetadata)>> _listeners = {};

  SessionManager({
    required PersistenceStrategy persistenceStrategy,
    PersistenceStrategy? archiveStorage,
    Logger? logger,
  }) : _persistenceStrategy = persistenceStrategy,
       _archiveStorage = archiveStorage,
       _logger = logger ?? ChatMemoryLogger.loggerFor('SessionManager');

  /// Create a new session
  Future<SessionMetadata> createSession({
    String? sessionId,
    SessionConfig? config,
  }) async {
    final id = sessionId ?? _generateSessionId();
    final now = DateTime.now();
    final sessionConfig = config ?? const SessionConfig();

    try {
      final metadata = SessionMetadata(
        sessionId: id,
        title: sessionConfig.title ?? 'Session $id',
        description: sessionConfig.description,
        customData: sessionConfig.customData,
        createdAt: now,
        lastAccessedAt: now,
        state: SessionState.active,
        messageCount: 0,
        totalTokens: 0,
        participants: sessionConfig.initialParticipants,
        statistics: {'created': now.toUtc().toIso8601String()},
      );

      await _saveSessionMetadata(metadata);
      _activeSessions[id] = metadata;

      _logger.info('Created new session: $id');
      _notifyListeners('sessionCreated', metadata);

      return metadata;
    } catch (e, stackTrace) {
      ChatMemoryLogger.logError(
        _logger,
        'createSession',
        e,
        stackTrace: stackTrace,
        params: {'sessionId': id, 'config': sessionConfig.toString()},
        shouldRethrow: true,
      );
      rethrow;
    }
  }

  /// Get session metadata
  Future<SessionMetadata?> getSession(String sessionId) async {
    try {
      // Check cache first
      if (_activeSessions.containsKey(sessionId)) {
        return _activeSessions[sessionId];
      }

      // Load from storage
      final metadata = await _loadSessionMetadata(sessionId);
      if (metadata != null && metadata.state == SessionState.active) {
        _activeSessions[sessionId] = metadata;
      }

      return metadata;
    } catch (e, stackTrace) {
      ChatMemoryLogger.logError(
        _logger,
        'getSession',
        e,
        stackTrace: stackTrace,
        params: {'sessionId': sessionId},
      );
      return null;
    }
  }

  /// Update session metadata
  Future<SessionMetadata> updateSession(
    String sessionId,
    SessionMetadata Function(SessionMetadata) updater,
  ) async {
    try {
      final current = await getSession(sessionId);
      if (current == null) {
        throw ChatMemoryException(
          'Session not found: $sessionId',
          context: ErrorContext(
            operation: 'updateSession',
            component: 'SessionManager',
            params: {'sessionId': sessionId},
          ),
        );
      }

      final updated = updater(current).copyWith(lastAccessedAt: DateTime.now());
      await _saveSessionMetadata(updated);

      if (updated.state == SessionState.active) {
        _activeSessions[sessionId] = updated;
      } else {
        _activeSessions.remove(sessionId);
      }

      _notifyListeners('sessionUpdated', updated);
      return updated;
    } catch (e, stackTrace) {
      ChatMemoryLogger.logError(
        _logger,
        'updateSession',
        e,
        stackTrace: stackTrace,
        params: {'sessionId': sessionId},
        shouldRethrow: true,
      );
      rethrow;
    }
  }

  /// Add message to session and update statistics
  Future<void> addMessage(String sessionId, Message message) async {
    await updateSession(sessionId, (metadata) {
      final tokenCount = _estimateTokens(message.content);
      return metadata.copyWith(
        messageCount: metadata.messageCount + 1,
        totalTokens: metadata.totalTokens + tokenCount,
        statistics: {
          ...metadata.statistics,
          'lastMessageAt': DateTime.now().toUtc().toIso8601String(),
        },
      );
    });
  }

  /// Suspend a session
  Future<SessionMetadata> suspendSession(String sessionId) async {
    return updateSession(
      sessionId,
      (metadata) => metadata.copyWith(state: SessionState.suspended),
    );
  }

  /// Activate a suspended session
  Future<SessionMetadata> activateSession(String sessionId) async {
    return updateSession(
      sessionId,
      (metadata) => metadata.copyWith(state: SessionState.active),
    );
  }

  /// Archive a session
  Future<SessionMetadata> archiveSession(String sessionId) async {
    try {
      final metadata = await updateSession(
        sessionId,
        (m) => m.copyWith(state: SessionState.archived),
      );

      if (_archiveStorage != null) {
        final messages = await _persistenceStrategy.loadMessages();
        final sessionMessages = messages
            .where((m) => m.metadata?['sessionId'] == sessionId)
            .toList();

        if (sessionMessages.isNotEmpty) {
          await _archiveStorage.saveMessages(sessionMessages);
          await _persistenceStrategy.deleteMessages(
            sessionMessages.map((m) => m.id).toList(),
          );
        }
      }

      _logger.info('Archived session: $sessionId');
      _notifyListeners('sessionArchived', metadata);
      return metadata;
    } catch (e, stackTrace) {
      ChatMemoryLogger.logError(
        _logger,
        'archiveSession',
        e,
        stackTrace: stackTrace,
        params: {'sessionId': sessionId},
        shouldRethrow: true,
      );
      rethrow;
    }
  }

  /// Terminate a session permanently
  Future<SessionMetadata> terminateSession(String sessionId) async {
    return updateSession(
      sessionId,
      (metadata) => metadata.copyWith(
        state: SessionState.terminated,
        terminatedAt: DateTime.now(),
      ),
    );
  }

  /// Search sessions with filters
  Future<List<SessionMetadata>> searchSessions({
    SessionFilter? filter,
    int limit = 100,
    int offset = 0,
  }) async {
    try {
      final allSessions = await _getAllSessionMetadata();
      final filtered = allSessions.where(
        (session) => _matchesFilter(session, filter),
      );

      return filtered.skip(offset).take(limit).toList();
    } catch (e, stackTrace) {
      ChatMemoryLogger.logError(
        _logger,
        'searchSessions',
        e,
        stackTrace: stackTrace,
        params: {'filter': filter.toString(), 'limit': limit, 'offset': offset},
      );
      return [];
    }
  }

  /// Get active sessions
  Future<List<SessionMetadata>> getActiveSessions() async {
    return searchSessions(
      filter: const SessionFilter(state: SessionState.active),
    );
  }

  /// Clean up old sessions based on age and state
  Future<int> cleanupSessions({
    Duration? olderThan,
    List<SessionState>? states,
  }) async {
    final cutoff = olderThan != null
        ? DateTime.now().subtract(olderThan)
        : DateTime.now().subtract(const Duration(days: 90));

    final targetStates =
        states ?? [SessionState.terminated, SessionState.archived];

    try {
      final sessions = await searchSessions();
      final toCleanup = sessions.where(
        (session) =>
            targetStates.contains(session.state) &&
            session.lastAccessedAt.isBefore(cutoff),
      );

      var cleanedCount = 0;
      for (final session in toCleanup) {
        await _deleteSessionMetadata(session.sessionId);
        cleanedCount++;
      }

      _logger.info('Cleaned up $cleanedCount old sessions');
      return cleanedCount;
    } catch (e, stackTrace) {
      ChatMemoryLogger.logError(
        _logger,
        'cleanupSessions',
        e,
        stackTrace: stackTrace,
        params: {
          'olderThan': olderThan.toString(),
          'states': states.toString(),
        },
      );
      return 0;
    }
  }

  /// Add event listener
  void addEventListener(String event, Function(SessionMetadata) listener) {
    _listeners.putIfAbsent(event, () => []).add(listener);
  }

  /// Remove event listener
  void removeEventListener(String event, Function(SessionMetadata) listener) {
    _listeners[event]?.remove(listener);
  }

  /// Generate unique session ID
  String _generateSessionId() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final random = (timestamp % 1000000).toString().padLeft(6, '0');
    return 'session_${timestamp}_$random';
  }

  /// Estimate token count for content
  int _estimateTokens(String content) {
    // Simple estimation: ~4 characters per token
    return (content.length / 4).ceil();
  }

  /// Save session metadata
  Future<void> _saveSessionMetadata(SessionMetadata metadata) async {
    // For now, store as a special message type
    // In production, you'd want a dedicated session metadata store
    final metadataMessage = Message(
      id: 'session_meta_${metadata.sessionId}',
      content: jsonEncode(metadata.toJson()),
      role: MessageRole.system,
      timestamp: metadata.lastAccessedAt,
      metadata: {'type': 'session_metadata', 'sessionId': metadata.sessionId},
    );

    await _persistenceStrategy.saveMessages([metadataMessage]);
  }

  /// Load session metadata
  Future<SessionMetadata?> _loadSessionMetadata(String sessionId) async {
    try {
      final messages = await _persistenceStrategy.loadMessages();
      final metadataMessage = messages.firstWhere(
        (m) => m.id == 'session_meta_$sessionId',
        orElse: () => throw StateError('Not found'),
      );

      final data = jsonDecode(metadataMessage.content) as Map<String, dynamic>;
      return SessionMetadata.fromJson(data);
    } catch (e) {
      return null;
    }
  }

  /// Get all session metadata
  Future<List<SessionMetadata>> _getAllSessionMetadata() async {
    final messages = await _persistenceStrategy.loadMessages();
    final metadataMessages = messages.where(
      (m) => m.metadata?['type'] == 'session_metadata',
    );

    final sessions = <SessionMetadata>[];
    for (final message in metadataMessages) {
      try {
        final data = jsonDecode(message.content) as Map<String, dynamic>;
        sessions.add(SessionMetadata.fromJson(data));
      } catch (e) {
        _logger.warning('Failed to parse session metadata: ${message.id}');
      }
    }

    return sessions;
  }

  /// Delete session metadata
  Future<void> _deleteSessionMetadata(String sessionId) async {
    await _persistenceStrategy.deleteMessages(['session_meta_$sessionId']);
  }

  /// Check if session matches filter
  bool _matchesFilter(SessionMetadata session, SessionFilter? filter) {
    if (filter == null) return true;

    if (filter.state != null && session.state != filter.state) {
      return false;
    }
    if (filter.titlePattern != null &&
        !session.title.contains(filter.titlePattern!)) {
      return false;
    }
    if (filter.createdAfter != null &&
        session.createdAt.isBefore(filter.createdAfter!)) {
      return false;
    }
    if (filter.createdBefore != null &&
        session.createdAt.isAfter(filter.createdBefore!)) {
      return false;
    }
    if (filter.minMessageCount != null &&
        session.messageCount < filter.minMessageCount!) {
      return false;
    }
    if (filter.maxMessageCount != null &&
        session.messageCount > filter.maxMessageCount!) {
      return false;
    }

    return true;
  }

  /// Notify event listeners
  void _notifyListeners(String event, SessionMetadata metadata) {
    final listeners = _listeners[event];
    if (listeners != null) {
      for (final listener in listeners) {
        try {
          listener(metadata);
        } catch (e) {
          _logger.warning('Event listener failed for $event: $e');
        }
      }
    }
  }
}

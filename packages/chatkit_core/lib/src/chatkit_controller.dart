import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io' show SocketException;
import 'dart:math' as math;

import 'package:meta/meta.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:collection/collection.dart';

import 'actions/client_tools.dart';
import 'api/api_client.dart';
import 'errors.dart';
import 'events/events.dart';
import 'models/attachments.dart';
import 'models/composer_state.dart';
import 'models/entities.dart';
import 'models/request.dart';
import 'models/response.dart';
import 'models/page.dart';
import 'models/thread.dart';
import 'options.dart';
import 'utils/json.dart';
import 'utils/thread_item_mutations.dart';

class ChatKitController {
  ChatKitController(
    ChatKitOptions options, {
    ChatKitApiClient? apiClient,
  })  : _options = options,
        _apiClient = apiClient ?? ChatKitApiClient(apiConfig: options.api) {
    _apiClient.acceptLanguage = options.locale;
  }

  final ChatKitApiClient _apiClient;
  ChatKitOptions _options;
  final StreamController<ChatKitEvent> _eventController =
      StreamController<ChatKitEvent>.broadcast();

  String? _currentThreadId;
  Thread? _activeThread;
  final Map<String, ThreadItem> _items = {};
  final Queue<String> _pendingUserMessages = Queue<String>();
  final Queue<_QueuedStreamingRequest> _offlineQueue =
      Queue<_QueuedStreamingRequest>();
  Timer? _offlineRetryTimer;
  Duration _offlineBackoff = const Duration(seconds: 2);
  bool _isStreaming = false;
  bool _isAppActive = true;
  bool _isLoadingThread = false;
  final Map<String, _StreamingTextBuffer> _streamingTextBuffers = {};
  Timer? _streamingDeltaTimer;
  final math.Random _random = math.Random();
  ChatComposerState _composerState = const ChatComposerState();
  bool _composerAvailable = true;
  String? _composerUnavailableReason;
  Timer? _composerAvailabilityTimer;
  bool _handshakeInProgress = false;
  Timer? _resumeFetchTimer;
  DateTime? _lastForegroundFetch;

  Stream<ChatKitEvent> get events => _eventController.stream;

  ChatKitOptions get options => _options;

  set options(ChatKitOptions value) {
    _options = value;
    _apiClient.acceptLanguage = value.locale;
  }

  String? get currentThreadId => _currentThreadId;
  Thread? get activeThread => _activeThread;
  List<ThreadItem> get threadItems => _items.values.toList()
    ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

  ThreadItem? threadItemById(String id) => _items[id];

  ChatComposerState get composerState => _composerState;

  void _emitLog(String name, [Map<String, Object?> data = const {}]) {
    final payload = data.isEmpty
        ? const <String, Object?>{}
        : Map<String, Object?>.unmodifiable(Map<String, Object?>.from(data));
    _eventController.add(
      ChatKitLogEvent(name: name, data: payload),
    );
    _options.onLog?.call(name, payload);
  }

  void _ensureIdle({bool allowThreadLoad = false}) {
    if (!_isAppActive) {
      throw ChatKitBusyException(
        'Cannot perform this action while the app is backgrounded.',
      );
    }
    if (_isStreaming) {
      throw ChatKitStreamingInProgressException(
        'Cannot perform this action while a response is streaming.',
      );
    }
    if (!allowThreadLoad && _isLoadingThread) {
      throw ChatKitBusyException(
        'Cannot perform this action while a thread is loading.',
      );
    }
  }

  Future<void> focusComposer() async {
    _eventController.add(const ChatKitComposerFocusEvent());
  }

  void handleAppBackgrounded() {
    if (!_isAppActive) {
      return;
    }
    _isAppActive = false;
    _resumeFetchTimer?.cancel();
    _resumeFetchTimer = null;
    if (_isStreaming) {
      _emitLog(
        'transport.cancelled',
        const {'reason': 'background'},
      );
      _apiClient.cancelActiveStream();
      _isStreaming = false;
    } else {
      _apiClient.cancelActiveStream();
    }
    _emitLog(
      'app.lifecycle',
      const {'state': 'background'},
    );
  }

  void handleAppForegrounded({bool forceRefresh = false}) {
    if (_isAppActive) {
      return;
    }
    _isAppActive = true;
    _emitLog(
      'app.lifecycle',
      const {'state': 'foreground'},
    );
    if (_currentThreadId == null) {
      return;
    }
    final now = DateTime.now();
    final since = _lastForegroundFetch;
    final cooldown = const Duration(seconds: 3);
    if (forceRefresh || since == null || now.difference(since) >= cooldown) {
      _lastForegroundFetch = now;
      unawaited(fetchUpdates());
      return;
    }

    final remaining = cooldown - now.difference(since);
    _resumeFetchTimer?.cancel();
    _resumeFetchTimer = Timer(remaining, () {
      if (!_isAppActive) {
        return;
      }
      _lastForegroundFetch = DateTime.now();
      unawaited(fetchUpdates());
    });
  }

  Future<void> setThreadId(String? threadId) async {
    _ensureIdle();
    if (threadId == null) {
      if (_currentThreadId == null && _activeThread == null) {
        return;
      }
      _currentThreadId = null;
      _activeThread = null;
      _items.clear();
      _pendingUserMessages.clear();
      _eventController.add(
        ChatKitThreadChangeEvent(threadId: null, thread: null),
      );
      return;
    }

    final isSameThread = threadId == _currentThreadId;
    _currentThreadId = threadId;
    if (!isSameThread) {
      _pendingUserMessages.clear();
    }
    await _loadThread(
      threadId: threadId,
      emitThreadChange: true,
    );
  }

  Future<void> sendUserMessage({
    required String text,
    Object? reply,
    List<Map<String, Object?>>? attachments,
    bool newThread = false,
    Map<String, Object?> metadata = const {},
    List<Entity>? tags,
  }) async {
    _ensureIdle();

    final attachmentModels = (attachments ?? const [])
        .map((json) => ChatKitAttachment.fromJson(json))
        .toList(growable: false);

    final effectiveTags = tags ?? _composerState.tags;
    String? replyText;
    if (reply is String) {
      replyText = _quotedTextForItem(reply) ?? _composerState.replyPreviewText;
    } else if (reply is Map<String, Object?>) {
      final replyId = reply['id'] as String?;
      replyText = (reply['text'] as String?) ??
          (replyId != null ? _quotedTextForItem(replyId) : null) ??
          _composerState.replyPreviewText;
    } else {
      replyText = _composerState.replyPreviewText;
    }

    final contents = <UserMessageContent>[];
    for (final tag in effectiveTags) {
      contents.add(
        UserMessageContent.tag(
          id: tag.id,
          text: tag.title,
          data: tag.data,
          interactive: tag.interactive ?? true,
        ),
      );
    }
    if (text.isNotEmpty || contents.isEmpty) {
      contents.add(UserMessageContent.text(text));
    }

    final userMessage = UserMessageInput(
      content: contents,
      attachmentIds: attachmentIdsFrom(attachmentModels),
      quotedText: replyText,
      inferenceOptions: _buildInferenceOptions(),
    );

    ThreadItem? pendingItem;
    if (!newThread && _currentThreadId != null) {
      final pendingId = 'pending-${DateTime.now().microsecondsSinceEpoch}';
      pendingItem = ThreadItem(
        id: pendingId,
        threadId: _currentThreadId!,
        createdAt: DateTime.now(),
        type: 'user_message',
        role: 'user',
        content: contents.map((entry) => entry.toJson()).toList(),
        attachments: attachmentModels,
        metadata: const {'pending': true},
        raw: {
          'id': pendingId,
          'type': 'user_message',
          'content': contents.map((entry) => entry.toJson()).toList(),
          'pending': true,
        },
      );
      _items[pendingId] = pendingItem;
      _pendingUserMessages.add(pendingId);
      _eventController.add(
        ChatKitThreadEvent(
          streamEvent: ThreadItemAddedEvent(item: pendingItem),
        ),
      );
    }

    final request = _currentThreadId == null || newThread
        ? threadsCreate(input: userMessage, metadata: metadata)
        : threadsAddUserMessage(
            threadId: _currentThreadId!,
            input: userMessage,
            metadata: metadata,
          );

    try {
      await _runStreamingRequest(
        request,
        pendingRequestId: pendingItem?.id,
      );
    } catch (error) {
      if (pendingItem != null) {
        _removePendingPlaceholder(pendingItem.id);
      }
      rethrow;
    }
    await setComposerValue(
      text: '',
      reply: null,
      attachments: const [],
      tags: const <Entity>[],
    );
  }

  Future<void> setComposerValue({
    String? text,
    Object? reply,
    List<Map<String, Object?>>? attachments,
    List<Entity>? tags,
    String? selectedModelId,
    String? selectedToolId,
  }) async {
    String? replyId;
    String? replyText;
    if (reply is String) {
      replyId = reply;
      replyText = _quotedTextForItem(reply);
    } else if (reply is Map<String, Object?>) {
      replyId = reply['id'] as String?;
      replyText = (reply['text'] as String?) ??
          (replyId != null ? _quotedTextForItem(replyId) : null);
    } else {
      replyId = null;
      replyText = null;
    }

    _composerState = _composerState.copyWith(
      text: text ?? _composerState.text,
      replyToItemId: replyId,
      replyPreviewText: replyText,
      attachments: attachments == null
          ? _composerState.attachments
          : attachments.map(ChatKitAttachment.fromJson).toList(growable: false),
      tags: tags ?? _composerState.tags,
      selectedModelId: selectedModelId ?? _composerState.selectedModelId,
      selectedToolId: selectedToolId ?? _composerState.selectedToolId,
    );
    _eventController.add(
      ChatKitComposerUpdatedEvent(state: _composerState),
    );
  }

  Future<void> fetchUpdates() async {
    final threadId = _currentThreadId;
    if (threadId == null) {
      return;
    }
    _ensureIdle();
    await _loadThread(
      threadId: threadId,
      emitThreadChange: true,
    );
  }

  Future<void> _loadThread({
    required String threadId,
    required bool emitThreadChange,
  }) async {
    if (_isLoadingThread) {
      throw ChatKitBusyException(
        'A thread load operation is already in progress.',
      );
    }
    _isLoadingThread = true;
    _eventController.add(
      ChatKitThreadLoadStartEvent(threadId: threadId),
    );

    try {
      final response = await _apiClient.send(
        threadsGetById(threadId: threadId),
      );
      final thread = Thread.fromJson(response);
      _activeThread = thread;
      _items
        ..clear()
        ..addEntries(
          thread.items.map(
            (item) => MapEntry(item.id, item),
          ),
        );
      _pendingUserMessages.clear();
      if (emitThreadChange) {
        _eventController.add(
          ChatKitThreadChangeEvent(threadId: threadId, thread: thread),
        );
      }
    } finally {
      _isLoadingThread = false;
      _eventController.add(
        ChatKitThreadLoadEndEvent(threadId: threadId),
      );
    }
  }

  Future<Page<ThreadMetadata>> listThreads({
    int limit = 20,
    String? after,
    String order = 'desc',
    String? section,
    String? query,
    bool? pinnedOnly,
    Map<String, Object?> metadata = const {},
  }) async {
    try {
      final requestMetadata = <String, Object?>{
        if (section != null && section.isNotEmpty) 'section': section,
        if (query != null && query.trim().isNotEmpty) 'query': query.trim(),
        if (pinnedOnly != null) 'pinned_only': pinnedOnly,
        ...metadata,
      };
      final response = await _apiClient.send(
        threadsList(
          limit: limit,
          after: after,
          order: order,
          metadata: requestMetadata,
        ),
      );
      return Page.fromJson(
        response,
        ThreadMetadata.fromJson,
      );
    } on ChatKitServerException catch (error) {
      if (error.statusCode == 401) {
        _eventController.add(const ChatKitAuthExpiredEvent());
        _setComposerAvailability(
          available: false,
          reason: 'auth',
          message: 'Authentication expired.',
        );
      } else if (error.statusCode == 429) {
        _handleRateLimit(error);
      } else if (_isStaleClientError(error)) {
        _handleStaleClientError(error);
      }
      rethrow;
    }
  }

  Future<void> deleteThread(String threadId) async {
    try {
      await _apiClient.send(threadsDelete(threadId: threadId));
    } on ChatKitServerException catch (error) {
      if (error.statusCode == 401) {
        _eventController.add(const ChatKitAuthExpiredEvent());
        _setComposerAvailability(
          available: false,
          reason: 'auth',
          message: 'Authentication expired.',
        );
      } else if (error.statusCode == 429) {
        _handleRateLimit(error);
      } else if (_isStaleClientError(error)) {
        _handleStaleClientError(error);
      }
      rethrow;
    }
    if (_currentThreadId == threadId) {
      _currentThreadId = null;
      _activeThread = null;
      _items.clear();
      _eventController.add(
        ChatKitThreadChangeEvent(threadId: null, thread: null),
      );
    }
  }

  Future<void> renameThread(String threadId, String title) async {
    try {
      final response = await _apiClient.send(
        threadsUpdate(threadId: threadId, updates: {'title': title}),
      );
      if (_currentThreadId == threadId) {
        final thread = Thread.fromJson(response);
        _activeThread = thread;
        _eventController.add(
          ChatKitThreadChangeEvent(threadId: threadId, thread: thread),
        );
      }
    } on ChatKitServerException catch (error) {
      if (error.statusCode == 401) {
        _eventController.add(const ChatKitAuthExpiredEvent());
        _setComposerAvailability(
          available: false,
          reason: 'auth',
          message: 'Authentication expired.',
        );
      } else if (error.statusCode == 429) {
        _handleRateLimit(error);
      } else if (_isStaleClientError(error)) {
        _handleStaleClientError(error);
      }
      rethrow;
    }
  }

  Future<void> submitFeedback({
    required String threadId,
    required List<String> itemIds,
    required String kind,
  }) async {
    try {
      await _apiClient.send(
        itemsFeedback(threadId: threadId, itemIds: itemIds, kind: kind),
      );
    } on ChatKitServerException catch (error) {
      if (error.statusCode == 401) {
        _eventController.add(const ChatKitAuthExpiredEvent());
        _setComposerAvailability(
          available: false,
          reason: 'auth',
          message: 'Authentication expired.',
        );
      } else if (error.statusCode == 429) {
        _handleRateLimit(error);
      } else if (_isStaleClientError(error)) {
        _handleStaleClientError(error);
      }
      rethrow;
    }
  }

  Future<void> retryAfterItem({
    required String threadId,
    required String itemId,
  }) async {
    _ensureIdle();
    final request = threadsRetryAfterItem(threadId: threadId, itemId: itemId);
    await _runStreamingRequest(request);
  }

  Future<void> sendCustomAction(
    Map<String, Object?> action, {
    String? itemId,
  }) async {
    _ensureIdle();
    if (_currentThreadId == null) {
      throw ChatKitConfigurationException(
        'Cannot send a custom action without an active thread.',
      );
    }
    _emitLog(
      'action.send',
      {
        'action_type': action['type'],
        if (itemId != null) 'item_id': itemId,
      },
    );
    final request = threadsCustomAction(
      threadId: _currentThreadId!,
      itemId: itemId,
      action: ChatKitAction.fromJson(action),
    );
    await _runStreamingRequest(request);
  }

  Future<void> sendAction(
    Map<String, Object?> action, {
    String? itemId,
  }) {
    return sendCustomAction(action, itemId: itemId);
  }

  void shareItem(String itemId) {
    final item = _items[itemId];
    if (item == null) {
      return;
    }
    _eventController.add(
      ChatKitShareEvent(
        threadId: item.threadId,
        itemId: item.id,
        content: item.content,
      ),
    );
  }

  Future<ChatKitAttachment> registerAttachment({
    required String name,
    required List<int> bytes,
    required String mimeType,
    int? size,
    void Function(int sentBytes, int totalBytes)? onProgress,
    bool Function()? isCancelled,
  }) async {
    final resolvedSize = size ?? bytes.length;
    onProgress?.call(0, resolvedSize);

    _emitLog(
      'attachments.upload.start',
      {
        'name': name,
        'mime_type': mimeType,
        'size': resolvedSize,
      },
    );

    ChatKitAttachment? attachment;
    try {
      if (_options.api is CustomApiConfig) {
        final config = _options.api as CustomApiConfig;
        if (config.uploadStrategy is DirectUploadStrategy) {
          attachment = await _performDirectUpload(
            config: config,
            strategy: config.uploadStrategy as DirectUploadStrategy,
            name: name,
            mimeType: mimeType,
            bytes: bytes,
            resolvedSize: resolvedSize,
            onProgress: onProgress,
            isCancelled: isCancelled,
          );
        }
      }

      if (attachment == null) {
        Map<String, Object?> response;
        try {
          response = await _apiClient.send(
            attachmentsCreate(
              name: name,
              size: resolvedSize,
              mimeType: mimeType,
            ),
          );
        } on ChatKitServerException catch (error) {
          if (error.statusCode == 401) {
            _eventController.add(const ChatKitAuthExpiredEvent());
            _setComposerAvailability(
              available: false,
              reason: 'auth',
              message: 'Authentication expired.',
            );
          } else if (error.statusCode == 429) {
            _handleRateLimit(error);
          } else if (_isStaleClientError(error)) {
            _handleStaleClientError(error);
          }
          rethrow;
        }

        attachment = ChatKitAttachment.fromJson(response);
        if (attachment.uploadUrl != null) {
          await _uploadToUrl(
            attachment.uploadUrl!,
            bytes,
            mimeType,
            onProgress: onProgress,
            isCancelled: isCancelled,
          );
        }
      }

      onProgress?.call(resolvedSize, resolvedSize);
      _emitLog(
        'attachments.upload.complete',
        {
          'attachment_id': attachment.id,
          'name': attachment.name,
          'mime_type': attachment.mimeType,
          'size': attachment.size ?? resolvedSize,
        },
      );
      return attachment;
    } catch (error) {
      _emitLog(
        'attachments.upload.error',
        {
          'name': name,
          'mime_type': mimeType,
          'size': resolvedSize,
          'error': error.toString(),
        },
      );
      rethrow;
    }
  }

  Future<ChatKitAttachment> _performDirectUpload({
    required CustomApiConfig config,
    required DirectUploadStrategy strategy,
    required String name,
    required String mimeType,
    required List<int> bytes,
    required int resolvedSize,
    void Function(int sentBytes, int totalBytes)? onProgress,
    bool Function()? isCancelled,
  }) async {
    final request = http.MultipartRequest(
      'POST',
      Uri.parse(strategy.uploadUrl),
    );
    request.headers['x-chatkit-sdk'] = 'chatkit-dart';
    if (config.domainKey != null) {
      request.headers['x-chatkit-domain-key'] = config.domainKey!;
    }
    if (config.headersBuilder != null) {
      final additional = await Future.value(config.headersBuilder!(request));
      if (additional.isNotEmpty) {
        request.headers.addAll(additional);
      }
    }
    final progressStream = _trackedByteStream(
      bytes,
      isCancelled: isCancelled,
      onProgress: onProgress,
    );
    request.files.add(
      http.MultipartFile(
        'file',
        progressStream,
        resolvedSize,
        filename: name,
        contentType: MediaType.parse(mimeType),
      ),
    );
    request.fields['name'] = name;
    request.fields['mime_type'] = mimeType;
    request.fields['size'] = resolvedSize.toString();

    final response = await request.send();
    final body = await response.stream.bytesToString();
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ChatKitServerException(
        'Direct upload failed with status ${response.statusCode}',
        statusCode: response.statusCode,
        error: body.isEmpty ? null : castMap(jsonDecode(body)),
      );
    }

    final payload =
        body.isEmpty ? <String, Object?>{} : castMap(jsonDecode(body));
    if (payload.isEmpty) {
      throw ChatKitException(
        'Direct upload endpoint must return attachment metadata.',
      );
    }
    return ChatKitAttachment.fromJson(payload);
  }

  Future<void> dispose() async {
    _offlineRetryTimer?.cancel();
    _composerAvailabilityTimer?.cancel();
    _resumeFetchTimer?.cancel();
    _streamingDeltaTimer?.cancel();
    await _apiClient.close();
    await _eventController.close();
  }

  Future<_StreamingOutcome> _runStreamingRequest(
    ChatKitRequest request, {
    bool isFollowUp = false,
    bool allowQueue = true,
    String? pendingRequestId,
  }) async {
    if (_isStreaming && !isFollowUp) {
      throw ChatKitStreamingInProgressException(
        'Streaming request already in flight.',
      );
    }

    if (!_isAppActive) {
      if (allowQueue) {
        _enqueueOfflineRequest(
          request,
          pendingRequestId: pendingRequestId,
          isFollowUp: isFollowUp,
        );
        return _StreamingOutcome.queued;
      }
      throw ChatKitBusyException(
        'Cannot perform this action while the app is backgrounded.',
      );
    }

    if (!isFollowUp) {
      _isStreaming = true;
    }

    final transport = _options.transport;
    final keepAliveTimeout =
        transport?.keepAliveTimeout ?? const Duration(seconds: 45);
    final initialBackoff =
        transport?.initialBackoff ?? const Duration(milliseconds: 500);
    final maxBackoff = transport?.maxBackoff ?? const Duration(seconds: 10);
    const maxAttempts = 5;
    var retryCount = 0;
    Duration? serverRetryHint;

    Object? capturedError;
    StackTrace? capturedStack;

    while (true) {
      final completer = Completer<void>();
      capturedError = null;
      capturedStack = null;

      try {
        await _apiClient.sendStreaming(
          request,
          onEvent: (event) async {
            await _handleStreamEvent(event);
          },
          onError: (error, stackTrace) {
            if (error is ChatKitServerException) {
              if (error.statusCode == 401) {
                _eventController.add(const ChatKitAuthExpiredEvent());
                _setComposerAvailability(
                  available: false,
                  reason: 'auth',
                  message: 'Authentication expired.',
                );
              } else if (error.statusCode == 429) {
                _handleRateLimit(error);
              } else if (_isStaleClientError(error)) {
                _handleStaleClientError(error);
              }
            }
            final message = error.toString();
            _eventController.add(
              ChatKitErrorEvent(
                error: message,
                allowRetry: true,
              ),
            );
            capturedError = error;
            capturedStack = stackTrace;
            if (!completer.isCompleted) {
              completer.completeError(error, stackTrace);
            }
          },
          onDone: () {
            if (!completer.isCompleted) {
              completer.complete();
            }
          },
          keepAliveTimeout: keepAliveTimeout,
          onKeepAliveTimeout: () {
            _emitLog(
              'transport.keepalive.timeout',
              {
                if (_currentThreadId != null) 'threadId': _currentThreadId,
              },
            );
          },
          onRetrySuggested: (duration) {
            if (duration.inMilliseconds > 0) {
              serverRetryHint = duration;
            }
          },
        );
      } on Object catch (error, stackTrace) {
        capturedError = error;
        capturedStack = stackTrace;
        if (error is ChatKitServerException) {
          if (error.statusCode == 401) {
            _eventController.add(const ChatKitAuthExpiredEvent());
            _setComposerAvailability(
              available: false,
              reason: 'auth',
              message: 'Authentication expired.',
            );
          } else if (error.statusCode == 429) {
            _handleRateLimit(error);
          } else if (_isStaleClientError(error)) {
            _handleStaleClientError(error);
          }
        }
        if (!completer.isCompleted) {
          completer.completeError(error, stackTrace);
        }
      }

      try {
        await completer.future;
        capturedError = null;
        break;
      } catch (error, stackTrace) {
        capturedError = error;
        capturedStack = stackTrace;
      }

      if (!_shouldRetryStreamingError(capturedError) ||
          retryCount >= maxAttempts) {
        if (!isFollowUp) {
          _isStreaming = false;
        }
        if (capturedError != null) {
          if (allowQueue && _shouldRetryStreamingError(capturedError)) {
            _enqueueOfflineRequest(
              request,
              pendingRequestId: pendingRequestId,
              isFollowUp: isFollowUp,
            );
            return _StreamingOutcome.queued;
          }
          Error.throwWithStackTrace(
            capturedError as Object,
            capturedStack ?? StackTrace.current,
          );
        }
        break;
      }

      retryCount += 1;
      final hint = serverRetryHint;
      final delay = _computeBackoffDelay(
        retryCount: retryCount,
        initialBackoff: initialBackoff,
        maxBackoff: maxBackoff,
        serverHint: hint,
      );
      serverRetryHint = null;
      _emitLog(
        'transport.retry',
        {
          'attempt': retryCount,
          'delay_ms': delay.inMilliseconds,
          if (hint != null) 'server_hint_ms': hint.inMilliseconds,
        },
      );
      await Future.delayed(delay);
    }

    if (!isFollowUp) {
      _isStreaming = false;
    }

    if (_composerUnavailableReason == null) {
      _setComposerAvailability(available: true);
    }
    return _StreamingOutcome.completed;
  }

  bool _shouldRetryStreamingError(Object? error) {
    if (error is TimeoutException) {
      return true;
    }
    if (error is SocketException) {
      return true;
    }
    if (error is ChatKitServerException) {
      final code = error.statusCode;
      if (code == null) {
        return false;
      }
      if (code == 429) {
        return true;
      }
      if (code >= 500 && code < 600) {
        return true;
      }
    }
    return false;
  }

  String? _quotedTextForItem(String itemId) {
    final item = _items[itemId];
    if (item == null) {
      return null;
    }
    final buffer = StringBuffer();
    var first = true;
    for (final part in item.content) {
      final type = part['type'] as String?;
      if (type == 'output_text' || type == 'input_text') {
        final text = part['text'] as String?;
        if (text != null && text.isNotEmpty) {
          if (!first) {
            buffer.writeln();
          }
          buffer.write(text);
          first = false;
        }
      }
    }
    final result = buffer.toString().trim();
    return result.isEmpty ? null : result;
  }

  Duration _computeBackoffDelay({
    required int retryCount,
    required Duration initialBackoff,
    required Duration maxBackoff,
    Duration? serverHint,
  }) {
    final minMillis = math.max(initialBackoff.inMilliseconds, 50);
    final maxMillis = math.max(maxBackoff.inMilliseconds, minMillis);
    int baseMillis;
    if (serverHint != null && serverHint.inMilliseconds > 0) {
      baseMillis = serverHint.inMilliseconds;
    } else {
      final factor = retryCount <= 0 ? 1 : 1 << (retryCount - 1);
      baseMillis = initialBackoff.inMilliseconds * factor;
    }
    baseMillis = baseMillis.clamp(minMillis, maxMillis);
    final jitterRange = (baseMillis * 0.2).round();
    final jitter = jitterRange <= 0
        ? 0
        : _random.nextInt(jitterRange * 2 + 1) - jitterRange;
    final withJitter = (baseMillis + jitter).clamp(minMillis, maxMillis);
    return Duration(milliseconds: withJitter);
  }

  void _setComposerAvailability({
    required bool available,
    String? reason,
    String? message,
    Duration? retryAfter,
  }) {
    final previousAvailable = _composerAvailable;
    final previousReason = _composerUnavailableReason;
    if (available) {
      if (_composerAvailable && _composerUnavailableReason == null) {
        return;
      }
      _composerAvailable = true;
      _composerUnavailableReason = null;
      _composerAvailabilityTimer?.cancel();
      _composerAvailabilityTimer = null;
      _eventController.add(
        ChatKitComposerAvailabilityEvent(
          available: true,
          reason: previousReason,
        ),
      );
      if (!previousAvailable) {
        if (previousReason == 'auth') {
          _options.hostedHooks?.onAuthRestored?.call();
        } else if (previousReason == 'stale_client') {
          _options.hostedHooks?.onAuthRestored?.call();
        }
      }
      return;
    }

    final normalizedReason = reason;
    if (!_composerAvailable &&
        _composerUnavailableReason == normalizedReason &&
        (message == null || message.isEmpty)) {
      return;
    }

    _composerAvailable = false;
    _composerUnavailableReason = normalizedReason;
    _composerAvailabilityTimer?.cancel();
    if (retryAfter != null && retryAfter > Duration.zero) {
      _composerAvailabilityTimer = Timer(retryAfter, () {
        _setComposerAvailability(
          available: true,
          reason: normalizedReason,
        );
      });
    }
    _eventController.add(
      ChatKitComposerAvailabilityEvent(
        available: false,
        reason: normalizedReason,
        message: message,
        retryAfter: retryAfter,
      ),
    );
    if (normalizedReason == 'auth') {
      _options.hostedHooks?.onAuthExpired?.call();
    }
  }

  void _handleRateLimit(ChatKitServerException error) {
    final wasRateLimited =
        !_composerAvailable && _composerUnavailableReason == 'rate_limit';
    final retryAfter = _parseRetryAfter(error.error);
    final message =
        _extractErrorMessage(error.error) ?? 'Rate limit reached. Try again.';
    _setComposerAvailability(
      available: false,
      reason: 'rate_limit',
      message: message,
      retryAfter: retryAfter,
    );
    if (!wasRateLimited) {
      _eventController.add(
        ChatKitNoticeEvent(
          message: message,
          title: 'Rate limit reached',
          level: ChatKitNoticeLevel.warning,
          code: 'rate_limit',
          retryAfter: retryAfter,
        ),
      );
    }
  }

  Duration? _parseRetryAfter(Map<String, Object?>? error) {
    if (error == null) {
      return null;
    }
    final retryAfterMs = error['retry_after_ms'] ??
        (error['metadata'] is Map
            ? (error['metadata'] as Map)['retry_after_ms']
            : null);
    final retryAfterSeconds = error['retry_after'] ??
        (error['metadata'] is Map
            ? (error['metadata'] as Map)['retry_after']
            : null);
    final nestedError = error['error'];

    Duration? fromValue(Object? value, {required bool milliseconds}) {
      if (value == null) return null;
      num? numeric;
      if (value is num) {
        numeric = value;
      } else if (value is String) {
        numeric = num.tryParse(value);
      }
      if (numeric == null || numeric <= 0) {
        return null;
      }
      if (milliseconds) {
        return Duration(milliseconds: numeric.round());
      }
      return Duration(milliseconds: (numeric * 1000).round());
    }

    final fromMs = fromValue(retryAfterMs, milliseconds: true);
    if (fromMs != null) {
      return fromMs;
    }
    final fromSeconds = fromValue(retryAfterSeconds, milliseconds: false);
    if (fromSeconds != null) {
      return fromSeconds;
    }

    if (nestedError is Map<String, Object?>) {
      return _parseRetryAfter(nestedError);
    }
    return null;
  }

  String? _extractErrorMessage(Map<String, Object?>? error) {
    if (error == null) {
      return null;
    }
    final messageCandidates = <Object?>[
      error['message'],
      error['detail'],
      error['error'],
    ];
    for (final candidate in messageCandidates) {
      if (candidate is String && candidate.trim().isNotEmpty) {
        return candidate.trim();
      }
      if (candidate is Map<String, Object?>) {
        final nested = _extractErrorMessage(candidate);
        if (nested != null) {
          return nested;
        }
      }
    }
    return null;
  }

  ChatKitNoticeLevel _noticeLevelFromString(String raw) {
    final normalized = raw.toLowerCase();
    switch (normalized) {
      case 'warning':
        return ChatKitNoticeLevel.warning;
      case 'error':
      case 'danger':
        return ChatKitNoticeLevel.error;
      default:
        return ChatKitNoticeLevel.info;
    }
  }

  bool _isStaleClientError(ChatKitServerException error) {
    if (error.statusCode == 409) {
      return true;
    }
    final code = _extractErrorCode(error.error)?.toLowerCase();
    if (code != null &&
        (code.contains('stale_client') || code.contains('client_stale'))) {
      return true;
    }
    final message = _extractErrorMessage(error.error)?.toLowerCase();
    if (message != null &&
        (message.contains('stale client') ||
            message.contains('client stale'))) {
      return true;
    }
    return false;
  }

  void _handleStaleClientError(ChatKitServerException error) {
    final retryAfter = _parseRetryAfter(error.error);
    final message = _extractErrorMessage(error.error) ??
        'This conversation is out of date. Refreshing…';
    _setComposerAvailability(
      available: false,
      reason: 'stale_client',
      message: message,
      retryAfter: retryAfter,
    );
    _eventController.add(
      ChatKitNoticeEvent(
        message: message,
        title: 'Conversation updated',
        level: ChatKitNoticeLevel.warning,
        code: _extractErrorCode(error.error) ?? 'stale_client',
        retryAfter: retryAfter,
      ),
    );
    _performHandshake();
  }

  Future<void> _performHandshake() async {
    if (_handshakeInProgress) {
      return;
    }
    _handshakeInProgress = true;
    _emitLog(
      'transport.handshake.start',
      const {'status': 'pending'},
    );
    try {
      final callback = _options.hostedHooks?.onStaleClient;
      if (callback != null) {
        await Future.sync(callback);
      }
      if (_currentThreadId != null) {
        await fetchUpdates();
      }
      _setComposerAvailability(available: true, reason: 'stale_client');
      _emitLog(
        'transport.handshake.complete',
        const {'status': 'ok'},
      );
    } catch (error, stackTrace) {
      _eventController.add(
        ChatKitErrorEvent(
          error: 'Failed to refresh client state: $error',
          allowRetry: true,
        ),
      );
      Zone.current.handleUncaughtError(error, stackTrace);
    } finally {
      _handshakeInProgress = false;
    }
  }

  String? _extractErrorCode(Map<String, Object?>? error) {
    if (error == null) {
      return null;
    }
    final candidates = <Object?>[
      error['code'],
      (error['error'] is Map<String, Object?>)
          ? (error['error'] as Map<String, Object?>)['code']
          : null,
    ];
    for (final candidate in candidates) {
      if (candidate is String && candidate.isNotEmpty) {
        return candidate;
      }
    }
    return null;
  }

  @visibleForTesting
  void debugHandleStreamEvent(ThreadStreamEvent event) {
    _handleStreamEvent(event);
  }

  Future<void> _handleStreamEvent(ThreadStreamEvent event) async {
    if (event is ThreadCreatedEvent) {
      _handleThreadCreated(event.thread);
      return;
    }
    if (event is ThreadUpdatedEvent) {
      _handleThreadUpdated(event.thread);
      return;
    }
    if (event is ThreadItemAddedEvent) {
      _handleItemAdded(event.item);
      return;
    }
    if (event is ThreadItemDoneEvent) {
      await _handleItemDone(event.item);
      return;
    }
    if (event is ThreadItemUpdatedEvent) {
      _handleItemUpdated(event.itemId, event.update);
      return;
    }
    if (event is ThreadItemRemovedEvent) {
      _items.remove(event.itemId);
      _eventController.add(ChatKitThreadEvent(streamEvent: event));
      return;
    }
    if (event is ThreadItemReplacedEvent) {
      _items[event.item.id] = event.item;
      _eventController.add(ChatKitThreadEvent(streamEvent: event));
      return;
    }
    if (event is ErrorEvent) {
      _eventController.add(
        ChatKitErrorEvent(
          error: event.message,
          code: event.code,
          allowRetry: event.allowRetry,
        ),
      );
      return;
    }
    if (event is NoticeEvent) {
      _handleNoticeEvent(event);
      return;
    }

    _eventController.add(ChatKitThreadEvent(streamEvent: event));
  }

  void _handleNoticeEvent(NoticeEvent event) {
    if (_isStaleClientNotice(event)) {
      _handleStaleClientNotice(event);
      return;
    }
    final level = _noticeLevelFromString(event.level);
    final retryAfter = _parseRetryAfter(event.data);
    _eventController.add(
      ChatKitNoticeEvent(
        message: event.message,
        title: event.title,
        level: level,
        code: event.code,
        retryAfter: retryAfter,
      ),
    );
    _emitLog(
      'notice',
      {
        'level': event.level,
        'message': event.message,
        if (event.title != null) 'title': event.title,
        if (event.code != null) 'code': event.code,
      },
    );
  }

  bool _isStaleClientNotice(NoticeEvent event) {
    final code = event.code?.toLowerCase();
    if (code == 'stale_client' || code == 'client_stale') {
      return true;
    }
    final normalized = event.message.trim().toLowerCase();
    return normalized.contains('stale client') ||
        normalized.contains('client stale');
  }

  void _handleStaleClientNotice(NoticeEvent event) {
    final retryAfter = _parseRetryAfter(event.data);
    final message = event.message.isNotEmpty
        ? event.message
        : 'This conversation changed in another session. Refreshing…';
    _setComposerAvailability(
      available: false,
      reason: 'stale_client',
      message: message,
      retryAfter: retryAfter,
    );
    _eventController.add(
      ChatKitNoticeEvent(
        message: message,
        title: event.title ?? 'Conversation updated',
        level: ChatKitNoticeLevel.warning,
        code: event.code ?? 'stale_client',
        retryAfter: retryAfter,
      ),
    );
    _performHandshake();
  }

  void _handleThreadCreated(Thread thread) {
    _currentThreadId = thread.metadata.id;
    _activeThread = thread;
    _items
      ..clear()
      ..addEntries(
        thread.items.map(
          (item) => MapEntry(item.id, item),
        ),
      );

    _eventController.add(
      ChatKitThreadChangeEvent(threadId: _currentThreadId, thread: thread),
    );
  }

  void _handleThreadUpdated(Thread thread) {
    _activeThread = thread;
    for (final item in thread.items) {
      _items[item.id] = item;
    }
    _eventController.add(
        ChatKitThreadEvent(streamEvent: ThreadUpdatedEvent(thread: thread)));
  }

  void _handleItemAdded(ThreadItem item) {
    if (item.type == 'user_message' && _pendingUserMessages.isNotEmpty) {
      final pendingId = _pendingUserMessages.removeFirst();
      final pendingItem = _items[pendingId];
      if (pendingItem != null && pendingItem.threadId == item.threadId) {
        _items.remove(pendingId);
        _eventController.add(
          ChatKitThreadEvent(
            streamEvent: ThreadItemRemovedEvent(itemId: pendingId),
          ),
        );
      } else {
        _pendingUserMessages.addFirst(pendingId);
      }
    }

    _items[item.id] = item;
    _eventController
        .add(ChatKitThreadEvent(streamEvent: ThreadItemAddedEvent(item: item)));

    if (item.type == 'assistant_message') {
      _eventController.add(
        ChatKitResponseStartEvent(
          threadId: item.threadId,
          item: item,
        ),
      );
    }
  }

  Future<void> _handleItemDone(ThreadItem item) async {
    _items[item.id] = item;
    _eventController
        .add(ChatKitThreadEvent(streamEvent: ThreadItemDoneEvent(item: item)));

    if (item.type == 'assistant_message') {
      _eventController.add(
        ChatKitResponseEndEvent(threadId: item.threadId, item: item),
      );
    } else if (item.type == 'client_tool_call') {
      await _handleClientToolCall(item);
    }
  }

  void _handleItemUpdated(String itemId, Map<String, Object?> update) {
    final type = update['type'] as String?;
    if (type == 'widget.streaming_text.value_delta') {
      _queueStreamingTextUpdate(itemId, update);
      return;
    }

    final previous = _items[itemId];
    final updated =
        previous != null ? applyThreadItemUpdate(previous, update) : null;
    if (updated != null) {
      _items[itemId] = updated;
    }
    _eventController.add(
      ChatKitThreadEvent(
        streamEvent: ThreadItemUpdatedEvent(
          itemId: itemId,
          update: update,
        ),
      ),
    );
  }

  Future<void> _handleClientToolCall(ThreadItem item) async {
    final handler = _options.onClientTool;
    if (handler == null) {
      _eventController.add(
        ChatKitErrorEvent(
          error: 'Client tool requested but no handler configured.',
          code: 'client_tool',
          allowRetry: false,
        ),
      );
      return;
    }

    final invocation = ChatKitClientToolInvocation(
      name: item.raw['name'] as String? ?? '',
      params: castMap(item.raw['arguments']),
      threadId: item.threadId,
      invocationId: item.raw['call_id'] as String? ?? item.id,
    );

    try {
      final result = await handler(invocation);
      final payload = normalizeClientToolResult(result);
      await _runStreamingRequest(
        threadsAddClientToolOutput(
          threadId: item.threadId,
          result: payload,
        ),
        isFollowUp: true,
        allowQueue: false,
      );
    } catch (error, stackTrace) {
      _eventController.add(
        ChatKitErrorEvent(
          error: error.toString(),
          code: 'client_tool',
          allowRetry: true,
        ),
      );
      Zone.current.handleUncaughtError(error, stackTrace);
    }
  }

  void _queueStreamingTextUpdate(String itemId, Map<String, Object?> update) {
    final componentId = update['component_id'] as String?;
    if (componentId == null) {
      final previous = _items[itemId];
      if (previous != null) {
        final updated = applyThreadItemUpdate(previous, update);
        _items[itemId] = updated;
      }
      _eventController.add(
        ChatKitThreadEvent(
          streamEvent: ThreadItemUpdatedEvent(
            itemId: itemId,
            update: update,
          ),
        ),
      );
      return;
    }

    final key = '$itemId::$componentId';
    final buffer = _streamingTextBuffers.putIfAbsent(
      key,
      () => _StreamingTextBuffer(itemId: itemId, componentId: componentId),
    );
    buffer.append(update);
    _streamingDeltaTimer ??= Timer(
      const Duration(milliseconds: 16),
      _flushStreamingTextUpdates,
    );
  }

  void _flushStreamingTextUpdates() {
    if (_streamingTextBuffers.isEmpty) {
      _streamingDeltaTimer?.cancel();
      _streamingDeltaTimer = null;
      return;
    }
    final entries = List<_StreamingTextBuffer>.from(
      _streamingTextBuffers.values,
    );
    _streamingTextBuffers.clear();
    _streamingDeltaTimer?.cancel();
    _streamingDeltaTimer = null;

    for (final buffer in entries) {
      final update = buffer.buildUpdate();
      final itemId = buffer.itemId;
      final previous = _items[itemId];
      if (previous != null) {
        final updated = applyThreadItemUpdate(previous, update);
        _items[itemId] = updated;
      }
      _eventController.add(
        ChatKitThreadEvent(
          streamEvent: ThreadItemUpdatedEvent(
            itemId: itemId,
            update: update,
          ),
        ),
      );
    }
  }

  InferenceOptions? _buildInferenceOptions() {
    final composer = _options.composer;
    final composerModels = composer?.models;
    final composerTools = composer?.tools;

    final selectedModelId = _composerState.selectedModelId ??
        composerModels?.firstWhereOrNull((model) => model.defaultSelected)?.id;
    final selectedToolId = _composerState.selectedToolId;

    if ((selectedModelId == null || selectedModelId.isEmpty) &&
        (selectedToolId == null || selectedToolId.isEmpty)) {
      if (composerModels == null && composerTools == null) {
        return null;
      }
    }

    return InferenceOptions(
      model: selectedModelId,
      toolChoice:
          selectedToolId != null ? ToolChoice(id: selectedToolId) : null,
    );
  }

  Future<void> _uploadToUrl(
    String url,
    List<int> bytes,
    String mimeType, {
    void Function(int sentBytes, int totalBytes)? onProgress,
    bool Function()? isCancelled,
  }) async {
    final client = http.Client();
    try {
      final request = http.StreamedRequest('PUT', Uri.parse(url))
        ..headers['content-type'] = mimeType;
      final total = bytes.length;
      var sent = 0;
      for (final chunk in _byteChunks(bytes)) {
        if (isCancelled?.call() == true) {
          await request.sink.close();
          throw ChatKitException('Upload cancelled');
        }
        request.sink.add(chunk);
        sent += chunk.length;
        onProgress?.call(sent, total);
      }
      await request.sink.close();
      final response = await client.send(request);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        final body = await response.stream.bytesToString();
        throw ChatKitServerException(
          'Failed to upload attachment to storage',
          statusCode: response.statusCode,
          error: body.isEmpty ? null : {'body': body},
        );
      }
    } finally {
      client.close();
    }
  }

  void _enqueueOfflineRequest(
    ChatKitRequest request, {
    String? pendingRequestId,
    required bool isFollowUp,
  }) {
    _offlineQueue.add(
      _QueuedStreamingRequest(
        request: request,
        pendingItemId: pendingRequestId,
        isFollowUp: isFollowUp,
      ),
    );
    _emitLog(
      'offline.queue',
      const {
        'message': 'Request queued due to connectivity issues.',
      },
    );
    _scheduleOfflineDrain();
  }

  void _scheduleOfflineDrain([Duration? delay]) {
    if (_offlineQueue.isEmpty) {
      return;
    }
    _offlineRetryTimer?.cancel();
    _offlineRetryTimer = Timer(delay ?? _offlineBackoff, () async {
      _offlineRetryTimer = null;
      if (_offlineQueue.isEmpty) {
        _offlineBackoff = const Duration(seconds: 2);
        return;
      }
      if (!_isAppActive) {
        _scheduleOfflineDrain(const Duration(seconds: 1));
        return;
      }
      if (_isStreaming) {
        _scheduleOfflineDrain(const Duration(seconds: 1));
        return;
      }

      final pending = _offlineQueue.removeFirst();
      try {
        final outcome = await _runStreamingRequest(
          pending.request,
          isFollowUp: pending.isFollowUp,
          allowQueue: false,
          pendingRequestId: pending.pendingItemId,
        );
        if (outcome == _StreamingOutcome.completed) {
          _offlineBackoff = const Duration(seconds: 2);
        }
      } catch (error, stackTrace) {
        if (_shouldRetryStreamingError(error)) {
          pending.attempts += 1;
          if (pending.attempts < _QueuedStreamingRequest.maxAttempts) {
            _offlineQueue.addFirst(pending);
            _offlineBackoff = Duration(
              milliseconds: math.min(
                _offlineBackoff.inMilliseconds * 2,
                60000,
              ),
            );
            _scheduleOfflineDrain(_offlineBackoff);
            return;
          }
        }

        _eventController.add(
          ChatKitErrorEvent(
            error: 'Failed to deliver request: $error',
            allowRetry: true,
          ),
        );
        _removePendingPlaceholder(pending.pendingItemId);
        Zone.current.handleUncaughtError(error, stackTrace);
      }

      if (_offlineQueue.isNotEmpty) {
        _scheduleOfflineDrain(const Duration(milliseconds: 500));
      } else {
        _offlineBackoff = const Duration(seconds: 2);
      }
    });
  }

  void _removePendingPlaceholder(String? pendingId) {
    if (pendingId == null) {
      return;
    }
    _pendingUserMessages.removeWhere((value) => value == pendingId);
    final removed = _items.remove(pendingId);
    if (removed != null) {
      _eventController.add(
        ChatKitThreadEvent(
          streamEvent: ThreadItemRemovedEvent(itemId: pendingId),
        ),
      );
    }
  }

  Stream<List<int>> _trackedByteStream(
    List<int> bytes, {
    void Function(int sentBytes, int totalBytes)? onProgress,
    bool Function()? isCancelled,
    int chunkSize = 64 * 1024,
  }) async* {
    final total = bytes.length;
    var offset = 0;
    while (offset < bytes.length) {
      if (isCancelled?.call() == true) {
        throw ChatKitException('Upload cancelled');
      }
      final end = math.min(offset + chunkSize, bytes.length);
      final chunk = bytes.sublist(offset, end);
      offset = end;
      onProgress?.call(offset, total);
      yield chunk;
    }
  }

  Iterable<List<int>> _byteChunks(List<int> bytes,
      {int chunkSize = 64 * 1024}) sync* {
    var offset = 0;
    while (offset < bytes.length) {
      final end = math.min(offset + chunkSize, bytes.length);
      yield bytes.sublist(offset, end);
      offset = end;
    }
  }
}

enum _StreamingOutcome {
  completed,
  queued,
}

class _QueuedStreamingRequest {
  _QueuedStreamingRequest({
    required this.request,
    this.pendingItemId,
    required this.isFollowUp,
  });

  static const int maxAttempts = 5;

  final ChatKitRequest request;
  final String? pendingItemId;
  final bool isFollowUp;
  int attempts = 0;
}

class _StreamingTextBuffer {
  _StreamingTextBuffer({
    required this.itemId,
    required this.componentId,
  });

  final String itemId;
  final String componentId;
  final StringBuffer _buffer = StringBuffer();
  Map<String, Object?>? _lastUpdate;
  bool? _done;

  void append(Map<String, Object?> update) {
    final delta = update['delta'] as String?;
    if (delta != null && delta.isNotEmpty) {
      _buffer.write(delta);
    }
    final done = update['done'];
    if (done is bool) {
      _done = done;
    }
    _lastUpdate = Map<String, Object?>.from(update);
  }

  Map<String, Object?> buildUpdate() {
    final base = Map<String, Object?>.from(
      _lastUpdate ?? const {'type': 'widget.streaming_text.value_delta'},
    );
    base['component_id'] = componentId;
    base['delta'] = _buffer.toString();
    if (_done != null) {
      base['done'] = _done;
    }
    return base;
  }
}

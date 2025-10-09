import 'package:meta/meta.dart';

import '../utils/json.dart';
import 'attachments.dart';

@immutable
class ChatKitRequest {
  const ChatKitRequest({
    required this.type,
    this.params = const {},
    this.metadata = const {},
  });

  final String type;
  final Map<String, Object?> params;
  final Map<String, Object?> metadata;

  bool get isStreaming => _streamingTypes.contains(type);

  Map<String, Object?> toJson() => {
        'type': type,
        if (params.isNotEmpty) 'params': params,
        if (metadata.isNotEmpty) 'metadata': metadata,
      };

  static const Set<String> _streamingTypes = {
    'threads.create',
    'threads.add_user_message',
    'threads.add_client_tool_output',
    'threads.retry_after_item',
    'threads.custom_action',
  };
}

ChatKitRequest threadsCreate({
  required UserMessageInput input,
  Map<String, Object?> metadata = const {},
}) {
  return ChatKitRequest(
    type: 'threads.create',
    params: {'input': input.toJson()},
    metadata: metadata,
  );
}

ChatKitRequest threadsAddUserMessage({
  required String threadId,
  required UserMessageInput input,
  Map<String, Object?> metadata = const {},
}) {
  return ChatKitRequest(
    type: 'threads.add_user_message',
    params: {
      'thread_id': threadId,
      'input': input.toJson(),
    },
    metadata: metadata,
  );
}

ChatKitRequest threadsAddClientToolOutput({
  required String threadId,
  required Map<String, Object?> result,
  Map<String, Object?> metadata = const {},
}) {
  return ChatKitRequest(
    type: 'threads.add_client_tool_output',
    params: {
      'thread_id': threadId,
      'result': result,
    },
    metadata: metadata,
  );
}

ChatKitRequest threadsRetryAfterItem({
  required String threadId,
  required String itemId,
  Map<String, Object?> metadata = const {},
}) {
  return ChatKitRequest(
    type: 'threads.retry_after_item',
    params: {
      'thread_id': threadId,
      'item_id': itemId,
    },
    metadata: metadata,
  );
}

ChatKitRequest threadsCustomAction({
  required String threadId,
  required ChatKitAction action,
  String? itemId,
  Map<String, Object?> metadata = const {},
}) {
  return ChatKitRequest(
    type: 'threads.custom_action',
    params: {
      'thread_id': threadId,
      if (itemId != null) 'item_id': itemId,
      'action': action.toJson(),
    },
    metadata: metadata,
  );
}

ChatKitRequest threadsGetById({
  required String threadId,
  Map<String, Object?> metadata = const {},
}) {
  return ChatKitRequest(
    type: 'threads.get_by_id',
    params: {
      'thread_id': threadId,
    },
    metadata: metadata,
  );
}

ChatKitRequest threadsList({
  int? limit,
  String? after,
  String? order,
  Map<String, Object?> metadata = const {},
}) {
  return ChatKitRequest(
    type: 'threads.list',
    params: {
      if (limit != null) 'limit': limit,
      if (after != null) 'after': after,
      if (order != null) 'order': order,
    },
    metadata: metadata,
  );
}

ChatKitRequest itemsList({
  required String threadId,
  int? limit,
  String? after,
  String? order,
  Map<String, Object?> metadata = const {},
}) {
  return ChatKitRequest(
    type: 'items.list',
    params: {
      'thread_id': threadId,
      if (limit != null) 'limit': limit,
      if (after != null) 'after': after,
      if (order != null) 'order': order,
    },
    metadata: metadata,
  );
}

ChatKitRequest attachmentsCreate({
  required String name,
  required int size,
  required String mimeType,
  Map<String, Object?> metadata = const {},
}) {
  return ChatKitRequest(
    type: 'attachments.create',
    params: {
      'name': name,
      'size': size,
      'mime_type': mimeType,
    },
    metadata: metadata,
  );
}

ChatKitRequest attachmentsDelete({
  required String attachmentId,
  Map<String, Object?> metadata = const {},
}) {
  return ChatKitRequest(
    type: 'attachments.delete',
    params: {
      'attachment_id': attachmentId,
    },
    metadata: metadata,
  );
}

ChatKitRequest itemsFeedback({
  required String threadId,
  required List<String> itemIds,
  required String kind,
  Map<String, Object?> metadata = const {},
}) {
  return ChatKitRequest(
    type: 'items.feedback',
    params: {
      'thread_id': threadId,
      'item_ids': itemIds,
      'kind': kind,
    },
    metadata: metadata,
  );
}

ChatKitRequest threadsUpdate({
  required String threadId,
  required Map<String, Object?> updates,
  Map<String, Object?> metadata = const {},
}) {
  return ChatKitRequest(
    type: 'threads.update',
    params: {
      'thread_id': threadId,
      ...updates,
    },
    metadata: metadata,
  );
}

ChatKitRequest threadsDelete({
  required String threadId,
  Map<String, Object?> metadata = const {},
}) {
  return ChatKitRequest(
    type: 'threads.delete',
    params: {
      'thread_id': threadId,
    },
    metadata: metadata,
  );
}

@immutable
class UserMessageInput {
  const UserMessageInput({
    required this.content,
    this.attachmentIds = const [],
    this.quotedText,
    this.inferenceOptions,
  });

  final List<UserMessageContent> content;
  final List<String> attachmentIds;
  final String? quotedText;
  final InferenceOptions? inferenceOptions;

  Map<String, Object?> toJson() => {
        'content': content.map((value) => value.toJson()).toList(),
        'attachments': attachmentIds,
        if (quotedText != null) 'quoted_text': quotedText,
        'inference_options': inferenceOptions?.toJson(),
      };
}

@immutable
sealed class UserMessageContent {
  const UserMessageContent();

  String get type;
  Map<String, Object?> toJson();

  factory UserMessageContent.text(String value) = UserMessageTextContent;

  factory UserMessageContent.tag({
    required String id,
    required String text,
    Map<String, Object?> data,
    bool interactive,
  }) = UserMessageTagContent;
}

class UserMessageTextContent extends UserMessageContent {
  const UserMessageTextContent(this.text);

  final String text;

  @override
  String get type => 'input_text';

  @override
  Map<String, Object?> toJson() => {
        'type': type,
        'text': text,
      };
}

class UserMessageTagContent extends UserMessageContent {
  const UserMessageTagContent({
    required this.id,
    required this.text,
    this.data = const {},
    this.interactive = false,
  });

  final String id;
  final String text;
  final Map<String, Object?> data;
  final bool interactive;

  @override
  String get type => 'input_tag';

  @override
  Map<String, Object?> toJson() => {
        'type': type,
        'id': id,
        'text': text,
        if (data.isNotEmpty) 'data': data,
        if (interactive) 'interactive': interactive,
      };
}

@immutable
class InferenceOptions {
  const InferenceOptions({
    this.toolChoice,
    this.model,
  });

  final ToolChoice? toolChoice;
  final String? model;

  Map<String, Object?> toJson() => {
        if (toolChoice != null) 'tool_choice': toolChoice!.toJson(),
        if (model != null) 'model': model,
      };
}

@immutable
class ToolChoice {
  const ToolChoice({
    required this.id,
  });

  final String id;

  Map<String, Object?> toJson() => {
        'id': id,
      };
}

@immutable
class ChatKitAction {
  const ChatKitAction({
    required this.type,
    required this.payload,
    this.handler,
    this.loadingBehavior,
  });

  final String type;
  final Map<String, Object?> payload;
  final String? handler;
  final String? loadingBehavior;

  Map<String, Object?> toJson() => {
        'type': type,
        'payload': payload,
        if (handler != null) 'handler': handler,
        if (loadingBehavior != null) 'loadingBehavior': loadingBehavior,
      };

  factory ChatKitAction.fromJson(Map<String, Object?> json) => ChatKitAction(
        type: json['type'] as String,
        payload: castMap(json['payload']),
        handler: json['handler'] as String?,
        loadingBehavior: json['loadingBehavior'] as String?,
      );
}

List<String> attachmentIdsFrom(
  Iterable<ChatKitAttachment> attachments,
) =>
    attachments.map((attachment) => attachment.id).toList(growable: false);

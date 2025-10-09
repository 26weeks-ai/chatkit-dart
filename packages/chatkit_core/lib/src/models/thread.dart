import 'package:meta/meta.dart';

import '../utils/json.dart';
import 'attachments.dart';

@immutable
class ThreadMetadata {
  const ThreadMetadata({
    required this.id,
    this.title,
    required this.createdAt,
    required this.status,
    this.metadata = const {},
  });

  final String id;
  final String? title;
  final DateTime createdAt;
  final ThreadStatus status;
  final Map<String, Object?> metadata;

  factory ThreadMetadata.fromJson(Map<String, Object?> json) {
    return ThreadMetadata(
      id: json['id'] as String,
      title: json['title'] as String?,
      createdAt: parseDateTime(json['created_at']) ?? DateTime.now().toUtc(),
      status: ThreadStatus.fromJson(json['status']),
      metadata: castMap(json['metadata']),
    );
  }

  Map<String, Object?> toJson() => {
        'id': id,
        if (title != null) 'title': title,
        'created_at': createdAt.toIso8601String(),
        'status': status.toJson(),
        if (metadata.isNotEmpty) 'metadata': metadata,
      };
}

@immutable
class ThreadStatus {
  const ThreadStatus._(this.type, {this.reason});

  factory ThreadStatus.fromJson(Object? value) {
    final map = castMap(value);
    final type = map['type'] as String? ?? 'active';
    return ThreadStatus._(type, reason: map['reason'] as String?);
  }

  final String type;
  final String? reason;

  Map<String, Object?> toJson() => {
        'type': type,
        if (reason != null) 'reason': reason,
      };

  bool get isClosed => type == 'closed';
  bool get isLocked => type == 'locked';
  bool get isActive => type == 'active';
}

@immutable
class ThreadItem {
  const ThreadItem({
    required this.id,
    required this.threadId,
    required this.createdAt,
    required this.type,
    this.role,
    this.content = const [],
    this.attachments = const [],
    this.metadata = const {},
    this.raw = const {},
  });

  final String id;
  final String threadId;
  final DateTime createdAt;
  final String type;
  final String? role;
  final List<Map<String, Object?>> content;
  final List<ChatKitAttachment> attachments;
  final Map<String, Object?> metadata;
  final Map<String, Object?> raw;

  factory ThreadItem.fromJson(Map<String, Object?> json) {
    final attachments = <ChatKitAttachment>[];
    final rawAttachments = json['attachments'];
    if (rawAttachments is List) {
      for (final attachment in rawAttachments) {
        attachments.add(ChatKitAttachment.fromJson(castMap(attachment)));
      }
    }

    return ThreadItem(
      id: json['id'] as String,
      threadId: json['thread_id'] as String,
      createdAt: parseDateTime(json['created_at']) ?? DateTime.now().toUtc(),
      type: json['type'] as String? ?? 'unknown',
      role: json['role'] as String?,
      content: castListOfMaps(json['content']),
      attachments: attachments,
      metadata: castMap(json['metadata']),
      raw: Map<String, Object?>.from(json),
    );
  }

  Map<String, Object?> toJson() => {
        'id': id,
        'thread_id': threadId,
        'created_at': createdAt.toIso8601String(),
        'type': type,
        if (role != null) 'role': role,
        if (content.isNotEmpty) 'content': content,
        if (attachments.isNotEmpty)
          'attachments':
              attachments.map((attachment) => attachment.toJson()).toList(),
        if (metadata.isNotEmpty) 'metadata': metadata,
      };

  ThreadItem copyWith({
    String? id,
    String? threadId,
    DateTime? createdAt,
    String? type,
    String? role,
    List<Map<String, Object?>>? content,
    List<ChatKitAttachment>? attachments,
    Map<String, Object?>? metadata,
    Map<String, Object?>? raw,
  }) {
    final updatedContent = content ?? this.content;
    final updatedRaw = raw != null
        ? Map<String, Object?>.from(raw)
        : {
            ...this.raw,
            if (content != null) 'content': updatedContent,
            if (attachments != null)
              'attachments': attachments.map((a) => a.toJson()).toList(),
            if (metadata != null) 'metadata': metadata,
          };

    return ThreadItem(
      id: id ?? this.id,
      threadId: threadId ?? this.threadId,
      createdAt: createdAt ?? this.createdAt,
      type: type ?? this.type,
      role: role ?? this.role,
      content: updatedContent,
      attachments: attachments ?? this.attachments,
      metadata: metadata ?? this.metadata,
      raw: updatedRaw,
    );
  }
}

@immutable
class Thread {
  const Thread({
    required this.metadata,
    this.items = const [],
    this.after,
    this.hasMore = false,
  });

  final ThreadMetadata metadata;
  final List<ThreadItem> items;
  final String? after;
  final bool hasMore;

  factory Thread.fromJson(Map<String, Object?> json) {
    return Thread(
      metadata: ThreadMetadata.fromJson(json),
      items: (castMap(json['items'])['data'] as List?)
              ?.map((item) => ThreadItem.fromJson(castMap(item)))
              .toList(growable: false) ??
          const [],
      after: castMap(json['items'])['after'] as String?,
      hasMore: castMap(json['items'])['has_more'] as bool? ?? false,
    );
  }

  Map<String, Object?> toJson() => {
        ...metadata.toJson(),
        'items': {
          'data': items.map((item) => item.toJson()).toList(),
          'after': after,
          'has_more': hasMore,
        },
      };
}

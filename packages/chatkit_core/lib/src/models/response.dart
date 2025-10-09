import 'package:meta/meta.dart';

import '../utils/json.dart';
import 'thread.dart';

@immutable
sealed class ThreadStreamEvent {
  const ThreadStreamEvent(this.type);

  final String type;

  factory ThreadStreamEvent.fromJson(Map<String, Object?> json) {
    final type = json['type'] as String? ?? '';
    switch (type) {
      case 'thread.created':
        return ThreadCreatedEvent(
          thread: Thread.fromJson(castMap(json['thread'])),
        );
      case 'thread.updated':
        return ThreadUpdatedEvent(
          thread: Thread.fromJson(castMap(json['thread'])),
        );
      case 'thread.item.added':
        return ThreadItemAddedEvent(
          item: ThreadItem.fromJson(castMap(json['item'])),
        );
      case 'thread.item.done':
        return ThreadItemDoneEvent(
          item: ThreadItem.fromJson(castMap(json['item'])),
        );
      case 'thread.item.updated':
        return ThreadItemUpdatedEvent(
          itemId: json['item_id'] as String,
          update: castMap(json['update']),
        );
      case 'thread.item.removed':
        return ThreadItemRemovedEvent(
          itemId: json['item_id'] as String,
        );
      case 'thread.item.replaced':
        return ThreadItemReplacedEvent(
          item: ThreadItem.fromJson(castMap(json['item'])),
        );
      case 'progress_update':
        return ProgressUpdateEvent(
          icon: json['icon'] as String?,
          text: json['text'] as String? ?? '',
        );
      case 'error':
        return ErrorEvent(
          code: json['code'] as String? ?? 'custom',
          message: json['message'] as String?,
          allowRetry: json['allow_retry'] as bool? ?? false,
        );
      case 'notice':
        return NoticeEvent(
          level: json['level'] as String? ?? 'info',
          message: json['message'] as String? ?? '',
          title: json['title'] as String?,
          code: json['code'] as String?,
          data: castMap(json['data']),
        );
      default:
        return UnknownStreamEvent(raw: json);
    }
  }
}

class ThreadCreatedEvent extends ThreadStreamEvent {
  ThreadCreatedEvent({
    required this.thread,
  }) : super('thread.created');

  final Thread thread;
}

class ThreadUpdatedEvent extends ThreadStreamEvent {
  ThreadUpdatedEvent({
    required this.thread,
  }) : super('thread.updated');

  final Thread thread;
}

class ThreadItemAddedEvent extends ThreadStreamEvent {
  ThreadItemAddedEvent({
    required this.item,
  }) : super('thread.item.added');

  final ThreadItem item;
}

class ThreadItemDoneEvent extends ThreadStreamEvent {
  ThreadItemDoneEvent({
    required this.item,
  }) : super('thread.item.done');

  final ThreadItem item;
}

class ThreadItemUpdatedEvent extends ThreadStreamEvent {
  ThreadItemUpdatedEvent({
    required this.itemId,
    required this.update,
  }) : super('thread.item.updated');

  final String itemId;
  final Map<String, Object?> update;
}

class ThreadItemRemovedEvent extends ThreadStreamEvent {
  ThreadItemRemovedEvent({
    required this.itemId,
  }) : super('thread.item.removed');

  final String itemId;
}

class ThreadItemReplacedEvent extends ThreadStreamEvent {
  ThreadItemReplacedEvent({
    required this.item,
  }) : super('thread.item.replaced');

  final ThreadItem item;
}

class ProgressUpdateEvent extends ThreadStreamEvent {
  ProgressUpdateEvent({
    required this.text,
    this.icon,
  }) : super('progress_update');

  final String? icon;
  final String text;
}

class ErrorEvent extends ThreadStreamEvent {
  ErrorEvent({
    required this.code,
    required this.message,
    required this.allowRetry,
  }) : super('error');

  final String code;
  final String? message;
  final bool allowRetry;
}

class NoticeEvent extends ThreadStreamEvent {
  NoticeEvent({
    required this.message,
    required this.level,
    this.title,
    this.code,
    this.data = const {},
  }) : super('notice');

  final String level;
  final String message;
  final String? title;
  final String? code;
  final Map<String, Object?> data;
}

class UnknownStreamEvent extends ThreadStreamEvent {
  UnknownStreamEvent({
    required this.raw,
  }) : super(raw['type'] as String? ?? 'unknown');

  final Map<String, Object?> raw;
}

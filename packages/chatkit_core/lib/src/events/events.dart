import 'package:meta/meta.dart';

import '../models/composer_state.dart';
import '../models/response.dart';
import '../models/thread.dart';

@immutable
sealed class ChatKitEvent {
  const ChatKitEvent(this.type);

  final String type;
}

class ChatKitThreadChangeEvent extends ChatKitEvent {
  ChatKitThreadChangeEvent({
    required this.threadId,
    this.thread,
  }) : super('chatkit.thread.change');

  final String? threadId;
  final Thread? thread;
}

class ChatKitThreadLoadStartEvent extends ChatKitEvent {
  ChatKitThreadLoadStartEvent({
    required this.threadId,
  }) : super('chatkit.thread.load.start');

  final String threadId;
}

class ChatKitThreadLoadEndEvent extends ChatKitEvent {
  ChatKitThreadLoadEndEvent({
    required this.threadId,
  }) : super('chatkit.thread.load.end');

  final String threadId;
}

class ChatKitResponseStartEvent extends ChatKitEvent {
  ChatKitResponseStartEvent({
    required this.threadId,
    required this.item,
  }) : super('chatkit.response.start');

  final String threadId;
  final ThreadItem item;
}

class ChatKitResponseEndEvent extends ChatKitEvent {
  ChatKitResponseEndEvent({
    required this.threadId,
    required this.item,
  }) : super('chatkit.response.end');

  final String threadId;
  final ThreadItem item;
}

class ChatKitErrorEvent extends ChatKitEvent {
  ChatKitErrorEvent({
    required this.error,
    this.code,
    this.allowRetry = false,
  }) : super('chatkit.error');

  final String? code;
  final String? error;
  final bool allowRetry;
}

class ChatKitLogEvent extends ChatKitEvent {
  ChatKitLogEvent({
    required this.name,
    this.data = const {},
  }) : super('chatkit.log');

  final String name;
  final Map<String, Object?> data;
}

class ChatKitThreadEvent extends ChatKitEvent {
  ChatKitThreadEvent({
    required this.streamEvent,
  }) : super(streamEvent.type);

  final ThreadStreamEvent streamEvent;
}

class ChatKitComposerFocusEvent extends ChatKitEvent {
  const ChatKitComposerFocusEvent() : super('chatkit.composer.focus');
}

class ChatKitShareEvent extends ChatKitEvent {
  ChatKitShareEvent({
    required this.threadId,
    required this.itemId,
    required this.content,
  }) : super('chatkit.message.share');

  final String threadId;
  final String itemId;
  final List<Map<String, Object?>> content;
}

class ChatKitAuthExpiredEvent extends ChatKitEvent {
  const ChatKitAuthExpiredEvent() : super('chatkit.auth.expired');
}

class ChatKitComposerUpdatedEvent extends ChatKitEvent {
  ChatKitComposerUpdatedEvent({
    required this.state,
  }) : super('chatkit.composer.change');

  final ChatComposerState state;
}

enum ChatKitNoticeLevel { info, warning, error }

class ChatKitNoticeEvent extends ChatKitEvent {
  ChatKitNoticeEvent({
    required this.message,
    this.title,
    this.code,
    this.level = ChatKitNoticeLevel.info,
    this.retryAfter,
  }) : super('chatkit.notice');

  final String message;
  final String? title;
  final String? code;
  final ChatKitNoticeLevel level;
  final Duration? retryAfter;
}

class ChatKitComposerAvailabilityEvent extends ChatKitEvent {
  const ChatKitComposerAvailabilityEvent({
    required this.available,
    this.reason,
    this.message,
    this.retryAfter,
  }) : super('chatkit.composer.availability');

  final bool available;
  final String? reason;
  final String? message;
  final Duration? retryAfter;
}

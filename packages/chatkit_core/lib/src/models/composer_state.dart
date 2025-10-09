import 'package:meta/meta.dart';

import 'attachments.dart';
import 'entities.dart';

@immutable
class ChatComposerState {
  const ChatComposerState({
    this.text = '',
    this.replyToItemId,
    this.replyPreviewText,
    this.attachments = const [],
    this.tags = const [],
    this.selectedModelId,
    this.selectedToolId,
  });

  final String text;
  final String? replyToItemId;
  final String? replyPreviewText;
  final List<ChatKitAttachment> attachments;
  final List<Entity> tags;
  final String? selectedModelId;
  final String? selectedToolId;

  ChatComposerState copyWith({
    String? text,
    String? replyToItemId,
    String? replyPreviewText,
    List<ChatKitAttachment>? attachments,
    List<Entity>? tags,
    String? selectedModelId,
    String? selectedToolId,
  }) {
    return ChatComposerState(
      text: text ?? this.text,
      replyToItemId: replyToItemId ?? this.replyToItemId,
      replyPreviewText: replyPreviewText ?? this.replyPreviewText,
      attachments: attachments ?? this.attachments,
      tags: tags ?? this.tags,
      selectedModelId: selectedModelId ?? this.selectedModelId,
      selectedToolId: selectedToolId ?? this.selectedToolId,
    );
  }
}

import 'package:meta/meta.dart';

@immutable
sealed class ChatKitAttachment {
  const ChatKitAttachment({
    required this.id,
    required this.name,
    required this.mimeType,
    this.uploadUrl,
    this.size,
  });

  final String id;
  final String name;
  final String mimeType;
  final String? uploadUrl;
  final int? size;

  String get type;

  Map<String, Object?> toJson();

  static ChatKitAttachment fromJson(Map<String, Object?> json) {
    final type = json['type'] as String? ?? 'file';
    final size = _parseSize(json['size'] ?? json['file_size']);
    switch (type) {
      case 'image':
        return ImageAttachment(
          id: json['id'] as String,
          name: json['name'] as String,
          mimeType: json['mime_type'] as String? ??
              json['mimeType'] as String? ??
              'application/octet-stream',
          previewUrl: json['preview_url'] as String? ??
              json['preview'] as String? ??
              '',
          uploadUrl: json['upload_url'] as String?,
          size: size,
        );
      default:
        return FileAttachment(
          id: json['id'] as String,
          name: json['name'] as String,
          mimeType: json['mime_type'] as String? ??
              json['mimeType'] as String? ??
              'application/octet-stream',
          uploadUrl: json['upload_url'] as String?,
          size: size,
        );
    }
  }
}

class FileAttachment extends ChatKitAttachment {
  const FileAttachment({
    required super.id,
    required super.name,
    required super.mimeType,
    super.uploadUrl,
    super.size,
  });

  @override
  String get type => 'file';

  @override
  Map<String, Object?> toJson() => {
        'type': type,
        'id': id,
        'name': name,
        'mime_type': mimeType,
        if (size != null) 'size': size,
        if (uploadUrl != null) 'upload_url': uploadUrl,
      };
}

class ImageAttachment extends ChatKitAttachment {
  const ImageAttachment({
    required super.id,
    required super.name,
    required super.mimeType,
    required this.previewUrl,
    super.uploadUrl,
    super.size,
  });

  final String previewUrl;

  @override
  String get type => 'image';

  @override
  Map<String, Object?> toJson() => {
        'type': type,
        'id': id,
        'name': name,
        'mime_type': mimeType,
        'preview_url': previewUrl,
        if (size != null) 'size': size,
        if (uploadUrl != null) 'upload_url': uploadUrl,
      };
}

int? _parseSize(Object? raw) {
  if (raw == null) {
    return null;
  }
  if (raw is num) {
    return raw.round();
  }
  if (raw is String) {
    return int.tryParse(raw);
  }
  return null;
}

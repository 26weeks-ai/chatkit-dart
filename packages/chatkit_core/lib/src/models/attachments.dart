import 'package:meta/meta.dart';

@immutable
sealed class ChatKitAttachment {
  const ChatKitAttachment({
    required this.id,
    required this.name,
    required this.mimeType,
    this.uploadUrl,
    this.size,
    this.uploadMethod,
    this.uploadFields,
    this.uploadHeaders,
  });

  final String id;
  final String name;
  final String mimeType;
  final String? uploadUrl;
  final int? size;
  final String? uploadMethod;
  final Map<String, String>? uploadFields;
  final Map<String, String>? uploadHeaders;

  String get type;

  Map<String, Object?> toJson();

  static ChatKitAttachment fromJson(Map<String, Object?> json) {
    final type = json['type'] as String? ?? 'file';
    final size = _parseSize(json['size'] ?? json['file_size']);
    final uploadMethod = _string(json['upload_method']);
    final uploadFields = _stringMap(json['upload_fields']);
    final uploadHeaders = _stringMap(json['upload_headers']);
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
          uploadMethod: uploadMethod,
          uploadFields: uploadFields,
          uploadHeaders: uploadHeaders,
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
          uploadMethod: uploadMethod,
          uploadFields: uploadFields,
          uploadHeaders: uploadHeaders,
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
    super.uploadMethod,
    super.uploadFields,
    super.uploadHeaders,
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
    super.uploadMethod,
    super.uploadFields,
    super.uploadHeaders,
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

String? _string(Object? value) {
  if (value == null) {
    return null;
  }
  if (value is String) {
    return value;
  }
  return value.toString();
}

Map<String, String>? _stringMap(Object? value) {
  if (value == null) {
    return null;
  }
  if (value is Map) {
    final map = <String, String>{};
    value.forEach((key, entryValue) {
      final keyString = _string(key);
      final valueString = _string(entryValue);
      if (keyString != null && valueString != null) {
        map[keyString] = valueString;
      }
    });
    return map.isEmpty ? null : map;
  }
  return null;
}

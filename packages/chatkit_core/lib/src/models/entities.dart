import 'package:meta/meta.dart';

@immutable
class Entity {
  const Entity({
    required this.id,
    required this.title,
    this.icon,
    this.interactive,
    this.group,
    this.data = const {},
  });

  final String id;
  final String title;
  final String? icon;
  final bool? interactive;
  final String? group;
  final Map<String, Object?> data;

  factory Entity.fromJson(Map<String, Object?> json) => Entity(
        id: json['id'] as String,
        title: (json['title'] as String?) ??
            (json['label'] as String?) ??
            '',
        icon: json['icon'] as String?,
        interactive: json['interactive'] as bool?,
        group: json['group'] as String?,
        data: Map<String, Object?>.from(
          (json['data'] as Map?) ??
              (json['metadata'] as Map?) ??
              const <String, Object?>{},
        ),
      );

  Map<String, Object?> toJson() => {
        'id': id,
        'title': title,
        if (icon != null) 'icon': icon,
        if (interactive != null) 'interactive': interactive,
        if (group != null) 'group': group,
        if (data.isNotEmpty) 'data': data,
      };

  @Deprecated('Use title')
  String get label => title;

  @Deprecated('Use data')
  Map<String, Object?> get metadata => data;
}

@immutable
class EntityPreview {
  const EntityPreview({
    required this.preview,
  });

  final Map<String, Object?>? preview;

  factory EntityPreview.fromJson(Map<String, Object?> json) => EntityPreview(
        preview: json['preview'] as Map<String, Object?>?,
      );

  Map<String, Object?> toJson() => {
        'preview': preview,
      };
}

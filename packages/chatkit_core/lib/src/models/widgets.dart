import 'package:meta/meta.dart';

import '../utils/json.dart';

@immutable
class WidgetRoot {
  const WidgetRoot({
    required this.type,
    this.id,
    this.key,
    this.props = const {},
    this.children = const [],
  });

  final String type;
  final String? id;
  final String? key;
  final Map<String, Object?> props;
  final List<WidgetComponent> children;

  factory WidgetRoot.fromJson(Map<String, Object?> json) {
    return WidgetRoot(
      type: json['type'] as String? ?? 'unknown',
      id: json['id'] as String?,
      key: json['key'] as String?,
      props: castMap(json['props']),
      children: (json['children'] as List?)
              ?.map((child) => WidgetComponent.fromJson(castMap(child)))
              .toList(growable: false) ??
          const [],
    );
  }

  Map<String, Object?> toJson() => {
        'type': type,
        if (id != null) 'id': id,
        if (key != null) 'key': key,
        if (props.isNotEmpty) 'props': props,
        if (children.isNotEmpty)
          'children': children.map((child) => child.toJson()).toList(),
      };
}

@immutable
class WidgetComponent {
  const WidgetComponent({
    required this.type,
    this.id,
    this.key,
    this.props = const {},
    this.children = const [],
  });

  final String type;
  final String? id;
  final String? key;
  final Map<String, Object?> props;
  final List<WidgetComponent> children;

  factory WidgetComponent.fromJson(Map<String, Object?> json) {
    return WidgetComponent(
      type: json['type'] as String? ?? 'unknown',
      id: json['id'] as String?,
      key: json['key'] as String?,
      props: castMap(json['props']),
      children: (json['children'] as List?)
              ?.map((child) => WidgetComponent.fromJson(castMap(child)))
              .toList(growable: false) ??
          const [],
    );
  }

  Map<String, Object?> toJson() => {
        'type': type,
        if (id != null) 'id': id,
        if (key != null) 'key': key,
        if (props.isNotEmpty) 'props': props,
        if (children.isNotEmpty)
          'children': children.map((child) => child.toJson()).toList(),
      };
}


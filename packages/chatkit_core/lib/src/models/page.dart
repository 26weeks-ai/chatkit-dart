import 'package:meta/meta.dart';

import '../utils/json.dart';

@immutable
class Page<T> {
  const Page({
    required this.data,
    this.hasMore = false,
    this.after,
  });

  final List<T> data;
  final bool hasMore;
  final String? after;

  factory Page.fromJson(
    Map<String, Object?> json,
    T Function(Map<String, Object?> json) factory,
  ) {
    final items = (json['data'] as List?)?.map((entry) {
          return factory(castMap(entry));
        }).toList() ??
        const [];
    return Page<T>(
      data: items,
      hasMore: json['has_more'] as bool? ?? false,
      after: json['after'] as String?,
    );
  }

  Map<String, Object?> toJson(Object? Function(T value) encoder) => {
        'data': data.map(encoder).toList(),
        'has_more': hasMore,
        if (after != null) 'after': after,
      };
}


DateTime? parseDateTime(Object? value) {
  if (value is DateTime) {
    return value.toUtc();
  }
  if (value is String && value.isNotEmpty) {
    return DateTime.tryParse(value)?.toUtc();
  }
  return null;
}

Map<String, Object?> castMap(Object? value) {
  if (value is Map<String, Object?>) {
    return value;
  }
  if (value is Map) {
    return value.map(
      (key, value) => MapEntry(key.toString(), value as Object?),
    );
  }
  return {};
}

List<Map<String, Object?>> castListOfMaps(Object? value) {
  if (value is List) {
    return value
        .map((entry) => castMap(entry))
        .toList(growable: false);
  }
  return const [];
}


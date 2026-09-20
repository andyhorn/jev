/// Decodes a JSON object with string-integer keys (e.g. `{"0": 0.57}`) into
/// a `Map<int, T>`, converting each value with [convert].
Map<int, T> decodeIntKeyedMap<T>(
  Map<String, dynamic> json,
  T Function(dynamic value) convert,
) {
  return json.map((key, value) => MapEntry(int.parse(key), convert(value)));
}

/// Encodes a `Map<int, T>` back into a JSON object with string keys,
/// converting each value with [convert].
Map<String, dynamic> encodeIntKeyedMap<T>(
  Map<int, T> map,
  dynamic Function(T value) convert,
) {
  return map.map((key, value) => MapEntry(key.toString(), convert(value)));
}

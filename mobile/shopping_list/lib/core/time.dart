/// Times travel as ISO-8601 UTC with milliseconds and are kept locally as
/// milliseconds since the epoch, which compare and sort without surprises.
int nowMs() => DateTime.now().millisecondsSinceEpoch;

String isoFromMs(int ms) => DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true).toIso8601String();

int? msFromIso(Object? iso) {
  if (iso is! String || iso.isEmpty) return null;
  return DateTime.tryParse(iso)?.millisecondsSinceEpoch;
}

/// A JSON object. PHP encodes an empty one as `[]`, so anything that is not a map counts as empty.
Map<String, dynamic> asMap(Object? value) => value is Map<String, dynamic> ? value : const {};

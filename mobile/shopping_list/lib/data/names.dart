/// A person as the app shows them: the name they chose, then the family's name ("João Alexandre").
/// Left as it is when the family has no name yet, or the name already ends with it.
String withFamilyName(String name, String family) {
  final first = name.trim();
  final last = family.trim();
  if (first.isEmpty || last.isEmpty) return first;

  final lower = first.toLowerCase();
  if (lower == last.toLowerCase() || lower.endsWith(' ${last.toLowerCase()}')) return first;

  return '$first $last';
}

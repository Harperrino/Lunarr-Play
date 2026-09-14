/// Search normalization intentionally keeps Unicode characters such as
/// German umlauts. SQLite's trigram tokenizer then matches the same visible
/// text users typed without leaking URLs or other provider metadata into the
/// index.
String normalizeSearchText(String value) {
  return value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
}

String normalizeSearchCategory(String? value) {
  return normalizeSearchText(value ?? '');
}

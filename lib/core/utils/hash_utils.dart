/// Generates a 100% stable, deterministic 31-bit integer ID for any string (e.g. file path)
/// across all Dart isolates, app restarts, and OS platforms (FNV-1a 32-bit algorithm).
int generateStableId(String input) {
  final normalized = input.toLowerCase().replaceAll(r'\', '/').trim();
  int hash = 0x811c9dc5;
  for (int i = 0; i < normalized.length; i++) {
    hash ^= normalized.codeUnitAt(i);
    hash = (hash * 0x01000193) & 0x7FFFFFFF;
  }
  return hash == 0 ? 1 : hash;
}

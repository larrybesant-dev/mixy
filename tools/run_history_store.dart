import 'dart:convert';
import 'dart:io';

class RunHistoryStore {
  RunHistoryStore(this.path);

  final String path;

  Future<List<Map<String, Object?>>> loadEntries() async {
    final File file = File(path);
    if (!file.existsSync()) {
      return <Map<String, Object?>>[];
    }

    final List<String> lines = await file.readAsLines();
    final List<Map<String, Object?>> entries = <Map<String, Object?>>[];

    for (final String line in lines) {
      final String trimmed = line.trim();
      if (trimmed.isEmpty) continue;

      try {
        final Object? decoded = jsonDecode(trimmed);
        if (decoded is Map<String, Object?>) {
          entries.add(decoded);
        }
      } catch (_) {
        // Ignore malformed history rows instead of breaking the gate.
      }
    }

    return entries;
  }

  Future<void> appendEntry(Map<String, Object?> entry) async {
    final File file = File(path);
    file.parent.createSync(recursive: true);

    final String existing = file.existsSync() ? await file.readAsString() : '';

    final String tmpPath =
        '$path.tmp.${DateTime.now().millisecondsSinceEpoch}.${pid.toString()}';
    final File tmp = File(tmpPath);
    await tmp.writeAsString('$existing${jsonEncode(entry)}\n');

    await tmp.rename(path);
  }
}

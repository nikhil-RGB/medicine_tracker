import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// Atomic JSON-file storage in the app documents directory.
///
/// Each logical file is written via temp-file + rename (atomic on the same
/// filesystem) and serialized through a per-file async mutex so two rapid
/// writes never interleave. After a successful load a `.bak` last-good copy is
/// kept for corrupt-file recovery; the in-progress `.tmp` is never read back.
class JsonStore {
  JsonStore._(this._dir);

  final Directory _dir;
  final Map<String, Future<void>> _locks = {};

  static Future<JsonStore> open() async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory('${docs.path}/medreminders');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return JsonStore._(dir);
  }

  File _file(String name) => File('${_dir.path}/$name');

  /// Reads and decodes [name]. On corruption falls back to the `.bak`, then to
  /// `null` (caller initializes empty).
  Future<Map<String, dynamic>?> read(String name) async {
    final primary = _file(name);
    final backup = _file('$name.bak');
    for (final f in [primary, backup]) {
      if (!await f.exists()) continue;
      try {
        final text = await f.readAsString();
        if (text.trim().isEmpty) continue;
        final data = jsonDecode(text);
        if (data is Map<String, dynamic>) {
          if (identical(f, primary)) {
            try {
              await primary.copy(backup.path);
            } catch (_) {/* best-effort backup refresh */}
          }
          return data;
        }
      } catch (_) {
        // try the next candidate (backup)
      }
    }
    return null;
  }

  /// Atomically writes [data] to [name], serialized per file (write-through).
  Future<void> write(String name, Map<String, dynamic> data) {
    final prev = _locks[name] ?? Future<void>.value();
    final next = prev.then((_) => _writeNow(name, data));
    _locks[name] = next.catchError((_) {});
    return next;
  }

  Future<void> _writeNow(String name, Map<String, dynamic> data) async {
    final target = _file(name);
    final tmp = _file('.tmp_$name');
    final text = const JsonEncoder.withIndent('  ').convert(data);
    await tmp.writeAsString(text, flush: true);
    try {
      await tmp.rename(target.path);
    } on FileSystemException {
      // Windows can't rename over an existing file; replace explicitly.
      if (await target.exists()) await target.delete();
      await tmp.rename(target.path);
    }
  }
}

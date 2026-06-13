import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// UTF-8 bytes prefixed with the BOM (EF BB BF) so Excel detects UTF-8 and
/// renders Vietnamese correctly.
List<int> csvBytesWithBom(String csv) => [0xEF, 0xBB, 0xBF, ...utf8.encode(csv)];

abstract class CsvExporter {
  /// Writes [csv] to a file named [filename]; returns the absolute path.
  Future<String> save(String filename, String csv);
}

class DiskCsvExporter implements CsvExporter {
  @override
  Future<String> save(String filename, String csv) async {
    final dir = await _targetDir();
    await dir.create(recursive: true); // guard: Android external dir may not exist yet
    final file = File(p.join(dir.path, filename));
    await file.writeAsBytes(csvBytesWithBom(csv), flush: true);
    return file.path;
  }

  Future<Directory> _targetDir() async {
    final downloads = await getDownloadsDirectory(); // desktop/iOS; Android -> null
    if (downloads != null) return downloads;
    final ext = await getExternalStorageDirectory(); // Android app external dir
    if (ext != null) return ext;
    return getApplicationDocumentsDirectory();
  }
}

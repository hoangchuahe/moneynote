import 'dart:ffi';
import 'dart:io';
import 'package:sqlite3/open.dart';

/// Call once (setUpAll) in any test that opens a Drift NativeDatabase.
/// On Windows the Dart VM has no bundled sqlite3, so point it at the DLL
/// copied into the project root (plan Task 4). Absolute path because the
/// test host doesn't search the project CWD for DLLs.
void setupSqliteForTests() {
  if (Platform.isWindows) {
    final dll = '${Directory.current.path}${Platform.pathSeparator}sqlite3.dll';
    open.overrideFor(OperatingSystem.windows, () => DynamicLibrary.open(dll));
  }
}

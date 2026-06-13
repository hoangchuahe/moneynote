/// Call once (setUpAll) in any test that opens a Drift NativeDatabase.
///
/// With sqlite3 3.x the native SQLite library is bundled via build hooks /
/// code assets, so tests no longer override the library path manually
/// (the old `package:sqlite3/open.dart` override API was removed in 3.0).
void setupSqliteForTests() {}

import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Opens the app's on-device SQLite database file, creating it on first
/// launch. This is the Beta 0 database connection — the on-device file
/// IS the source of truth (there is no backend yet), per
/// `STAGE1_BETA0_IMPLEMENTATION_PLAN.md` §13.
///
/// Uses `NativeDatabase.createInBackground`, which runs SQLite on a
/// background isolate so database work never blocks the UI thread — the
/// standard Flutter-target Drift connection pattern.
QueryExecutor openAppDatabaseConnection() {
  return LazyDatabase(() async {
    final Directory dir = await getApplicationDocumentsDirectory();
    final File file = File(p.join(dir.path, 'ai_financial_coach.sqlite'));
    return NativeDatabase.createInBackground(file);
  });
}

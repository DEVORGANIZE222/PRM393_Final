import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/roster_entry.dart';

class RosterImportResult {
  const RosterImportResult(this.imported, this.skipped);
  final int imported;
  final int skipped;
}

class AdminRosterService {
  AdminRosterService({FirebaseFirestore? firestore}) : _db = firestore ?? FirebaseFirestore.instance;
  final FirebaseFirestore _db;

  Stream<List<RosterEntry>> watchWhitelist() => _db.collection('allowedEmails').snapshots().map((snapshot) {
    final rows = snapshot.docs.map((doc) => RosterEntry.fromFirestore(doc.id, doc.data())).toList();
    rows.sort((a, b) => a.email.compareTo(b.email));
    return rows;
  });

  /// Imports only allowlist data. The mobile app remains owner of students/{uid}
  /// and fills that document after a student signs in.
  Future<RosterImportResult> importCsv(String csv) async {
    return importEntries(parseCsv(csv));
  }

  Future<RosterImportResult> importEntries(List<RosterEntry> entries) async {
    for (var offset = 0; offset < entries.length; offset += 450) {
      final batch = _db.batch();
      for (final entry in entries.skip(offset).take(450)) {
        batch.set(_db.collection('allowedEmails').doc(entry.email), {
          ...entry.toFirestore(),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
      await batch.commit();
    }
    return RosterImportResult(entries.length, 0);
  }

  Future<void> setEnabled(RosterEntry entry, bool enabled) => _db.collection('allowedEmails').doc(entry.email).set({
    'enabled': enabled,
    'updatedAt': FieldValue.serverTimestamp(),
  }, SetOptions(merge: true));

  Future<void> addSingleStudent(RosterEntry entry) => _db.collection('allowedEmails').doc(entry.email).set({
    ...entry.toFirestore(),
    'updatedAt': FieldValue.serverTimestamp(),
  }, SetOptions(merge: true));

  Future<void> deleteStudent(String email) => _db.collection('allowedEmails').doc(email).delete();

  static List<RosterEntry> parseCsv(String content) {
    final lines = content.split(RegExp(r'\r?\n')).where((line) => line.trim().isNotEmpty).toList();
    if (lines.length < 2) throw const FormatException('Use a CSV file with a header row and at least one student.');
    final headers = _splitRow(lines.first).map((cell) => cell.trim().toLowerCase().replaceAll(' ', '')).toList();
    int indexOf(List<String> names) => headers.indexWhere(names.contains);
    final emailIndex = indexOf(['email', 'emailaddress']);
    final nameIndex = indexOf(['fullname', 'name', 'studentname']);
    if (emailIndex < 0) throw const FormatException('The CSV must contain an Email column.');

    String value(List<String> row, int index) => index >= 0 && index < row.length ? row[index].trim() : '';
    final codeIndex = indexOf(['studentcode', 'code']);
    final majorIndex = indexOf(['major']);
    final cohortIndex = indexOf(['cohort']);
    final unique = <String, RosterEntry>{};
    for (final raw in lines.skip(1)) {
      final row = _splitRow(raw);
      final email = value(row, emailIndex).toLowerCase();
      if (!email.contains('@')) continue;
      unique[email] = RosterEntry(
        email: email,
        fullName: value(row, nameIndex),
        studentCode: value(row, codeIndex),
        major: value(row, majorIndex),
        cohort: value(row, cohortIndex),
      );
    }
    if (unique.isEmpty) throw const FormatException('No valid email was found in this CSV.');
    return unique.values.toList();
  }

  static List<String> _splitRow(String row) {
    final cells = <String>[];
    var buffer = StringBuffer();
    var quoted = false;
    for (var i = 0; i < row.length; i++) {
      final char = row[i];
      if (char == '"') {
        if (quoted && i + 1 < row.length && row[i + 1] == '"') {
          buffer.write('"');
          i++;
        } else {
          quoted = !quoted;
        }
      } else if (char == ',' && !quoted) {
        cells.add(buffer.toString());
        buffer = StringBuffer();
      } else {
        buffer.write(char);
      }
    }
    cells.add(buffer.toString());
    return cells;
  }
}

import 'dart:io';

import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../models/student.dart';
import '../models/team.dart';
import 'services.dart';

/// Generates the "Team summary" PDF from the same data My Team shows.
class PdfReportService implements ReportService {
  @override
  Future<File> buildTeamSummary({required Team team, required Student student, required DateTime generatedAt}) async {
    final green = PdfColor.fromHex('#15803D');
    final grey = PdfColor.fromHex('#596066');
    final stamp = DateFormat('dd MMM yyyy, HH:mm').format(generatedAt);
    final status = team.locked
        ? 'Locked · code ${team.lockCode}'
        : team.meetsSizeRule
        ? (team.hasLeader ? 'Ready to lock' : 'Leader not elected')
        : 'In formation · needs ${TeamRules.minMembers - team.memberCount} more';

    final doc = pw.Document(title: '${team.name} summary', author: 'EXEMatching');
    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        build: (context) => [
          pw.Text('EXEMatching · Team summary', style: pw.TextStyle(color: green, fontSize: 12)),
          pw.SizedBox(height: 6),
          pw.Text(team.name, style: pw.TextStyle(fontSize: 26, fontWeight: pw.FontWeight.bold)),
          pw.Text(team.topic, style: pw.TextStyle(fontSize: 14, color: grey)),
          pw.SizedBox(height: 16),
          pw.TableHelper.fromTextArray(
            headers: ['Item', 'Value'],
            data: [
              ['Status', status],
              [
                'Members',
                '${team.memberCount} of ${team.capacity} (rule: ${TeamRules.minMembers}-${TeamRules.maxMembers})',
              ],
              ['Leader', team.leader?.fullName ?? 'Not elected yet'],
              ['Supervisor', team.supervisor],
              ['Category', team.category],
              ['Technologies', team.tags.join(', ')],
              if (team.openRoles.isNotEmpty) ['Looking for', team.openRoles.join(', ')],
            ],
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
            headerDecoration: pw.BoxDecoration(color: green),
            cellPadding: const pw.EdgeInsets.all(6),
          ),
          pw.SizedBox(height: 20),
          pw.Text('Roster', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 8),
          pw.TableHelper.fromTextArray(
            headers: ['Name', 'Student ID', 'Role', 'Votes'],
            data: [
              for (final m in team.members)
                [
                  m.studentId == team.leaderId ? '${m.fullName} (Leader)' : m.fullName,
                  m.studentCode,
                  m.role,
                  '${team.votesFor(m.studentId)}',
                ],
            ],
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            cellPadding: const pw.EdgeInsets.all(6),
          ),
          pw.SizedBox(height: 24),
          pw.Text('Generated for ${student.studentCode} on $stamp.', style: pw.TextStyle(color: grey, fontSize: 10)),
        ],
      ),
    );

    final dir = await getTemporaryDirectory();
    final name = 'team-${team.code.toLowerCase()}-${DateFormat('yyyyMMdd-HHmm').format(generatedAt)}.pdf';
    final file = File('${dir.path}/$name');
    await file.writeAsBytes(await doc.save());
    return file;
  }
}

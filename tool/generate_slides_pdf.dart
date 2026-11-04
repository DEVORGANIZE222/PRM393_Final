import 'dart:io';
import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

// Presentation deck for PRM393 Lab 3, 16:9. Every number and every "verified" claim
// is read from the repository (junit.xml, evidence files, source), never typed in.
//   dart run tool/generate_slides_pdf.dart

const double kW = 960, kH = 540;

final green900 = PdfColor.fromHex('#052E16');
final green800 = PdfColor.fromHex('#14532D');
final green = PdfColor.fromHex('#15803D'); // AppColors.primary
final green100 = PdfColor.fromHex('#DCFCE7'); // AppColors.primaryContainer
final orange = PdfColor.fromHex('#B4530A'); // AppColors.accent
final orange100 = PdfColor.fromHex('#FDE8DA'); // AppColors.accentContainer
final ink = PdfColor.fromHex('#1A1D1E');
final muted = PdfColor.fromHex('#596066');
final line = PdfColor.fromHex('#E1E3E5');
final paper = PdfColor.fromHex('#F6F8F4');
final red = PdfColor.fromHex('#B91C1C');
final red100 = PdfColor.fromHex('#FEE2E2');
final blue = PdfColor.fromHex('#1D4ED8');
final blue100 = PdfColor.fromHex('#DBEAFE');

// Material icon code points (Flutter's Icons.*). tool/make_icon_font.py turns these into
// tool/fonts/material_icons_subset.ttf; rerun it after adding an icon here.
const iLogin = 0xe3b2, iLock = 0xe3ae, iGroups = 0xe2ee, iVote = 0xe32c, iCloud = 0xe16f, iBug = 0xe115;
const iBell = 0xe450, iInsights = 0xe347, iTune = 0xe683, iStorage = 0xe609, iShield = 0xe596, iTree = 0xe044;
const iRobot = 0xe5c5, iCheck = 0xe159, iCancel = 0xe139, iBolt = 0xe0ee, iFact = 0xe256, iWarn = 0xe6cc;
const iBulb = 0xe37b, iEast = 0xe216, iSearch = 0xe567, iPdf = 0xe4c0, iScience = 0xe55a, iGroupAdd = 0xe2ec;
const iUpload = 0xe175, iCode = 0xe176, iPalette = 0xe46b, iSpark = 0xe0b7, iPerson = 0xe491, iSchedule = 0xe556;
const iVerified = 0xe69a, iSync = 0xe632, iHidden = 0xe6be, iTrophy = 0xe22c, iQuote = 0xe2bc, iKey = 0xe6c7;

pw.Font? _font(List<String> paths) {
  for (final p in paths) {
    final f = File(p);
    if (f.existsSync()) return pw.Font.ttf(f.readAsBytesSync().buffer.asByteData());
  }
  return null;
}

/// Pass/fail per run for each test case in a pytest junit.xml; a teardown error counts as a failure.
Map<String, List<bool>> readJunit(String path) {
  final file = File(path);
  final outcome = <String, bool>{};
  if (file.existsSync()) {
    final xml = file.readAsStringSync();
    for (final m in RegExp(r'<testcase [^>]*name="(test_tc\d+[^"]*\[run\d+\])"[^>]*?(/>|>([\s\S]*?)</testcase>)').allMatches(xml)) {
      final failed = (m.group(3) ?? '').contains('<failure') || (m.group(3) ?? '').contains('<error');
      outcome[m.group(1)!] = (outcome[m.group(1)!] ?? true) && !failed;
    }
  }
  final runs = <String, List<bool>>{};
  for (final e in (outcome.entries.toList()..sort((a, b) => a.key.compareTo(b.key)))) {
    final id = RegExp(r'test_tc(\d+)').firstMatch(e.key)!.group(1)!;
    runs.putIfAbsent('TC-$id', () => []).add(e.value);
  }
  return runs;
}

int passedOf(Map<String, List<bool>> runs) => runs.values.expand((r) => r).where((ok) => ok).length;
int totalOf(Map<String, List<bool>> runs) => runs.values.expand((r) => r).length;

bool captured(List<String> files) => files.every((f) => File(f).existsSync());

int countMatches(String dir, RegExp pattern) {
  final d = Directory(dir);
  if (!d.existsSync()) return 0;
  return d
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'))
      .map((f) => pattern.allMatches(f.readAsStringSync()).length)
      .fold(0, (a, b) => a + b);
}

void main() async {
  // Segoe UI on Windows; the pdf package's Helvetica elsewhere.
  const fonts = 'C:/Windows/Fonts';
  final regular = _font(['$fonts/segoeui.ttf']);
  final bold = _font(['$fonts/segoeuib.ttf']);
  final semibold = _font(['$fonts/seguisb.ttf']) ?? bold;
  final light = _font(['$fonts/segoeuil.ttf']) ?? regular;
  final italic = _font(['$fonts/segoeuii.ttf']);
  final icons = _font(['tool/fonts/material_icons_subset.ttf']);

  final pdf = pw.Document(
    title: 'EXEMatching - PRM393 Lab 3 presentation',
    author: 'DEVORGANIZE222',
    theme: pw.ThemeData.withFont(base: regular, bold: bold, italic: italic, icons: icons),
  );

  // ---------------------------------------------------------------- data from the repo
  final finalRuns = readJunit('e2e_test/evidence/junit.xml');
  final attempts = <(String, Map<String, List<bool>>)>[
    ('Lượt 1', readJunit('e2e_test/evidence-attempt1/junit.xml')),
    ('Lượt 2', readJunit('e2e_test/evidence-attempt2/junit.xml')),
    ('Lượt cuối', finalRuns),
  ];
  final passed = passedOf(finalRuns), total = totalOf(finalRuns);
  final firebaseImport = RegExp(r"import 'package:(firebase|cloud_firestore)");
  final uiFirebaseImports = countMatches('lib/screens', firebaseImport) + countMatches('lib/widgets', firebaseImport);
  final transactions = countMatches('lib/firebase', RegExp(r'runTransaction\('));
  final rulesFile = File('firebase/firestore.rules');
  final rules = rulesFile.existsSync() ? rulesFile.readAsStringSync() : '';
  final hasOnly = RegExp(r'hasOnly\(\s*\[([^\]]*)\]').firstMatch(rules);
  final writableFields = hasOnly == null ? 0 : RegExp(r"'[^']+'").allMatches(hasOnly.group(1)!).length;

  const evidence = {
    'Authentication': ['evidence/console/console_auth_users.jpg'],
    'Firestore': ['evidence/console/console_firestore_teams.jpg', 'evidence/console/console_firestore_rules_teams.jpg'],
    'Storage': ['evidence/console/console_storage_files.jpg', 'evidence/console/console_storage_rules.jpg'],
    'Cloud Messaging': ['evidence/fcm/foreground_alerts.png', 'evidence/fcm/background_opened.png', 'evidence/fcm/terminated_opened.png'],
    'Analytics': [
      'evidence/debugview/debugview_login_user_id.jpg',
      'evidence/debugview/debugview_search_teams_params.jpg',
      'evidence/debugview/debugview_cast_vote_params.jpg',
    ],
    'Crashlytics': [
      'evidence/crashlytics/crashlytics_nonfatal_keys.jpg',
      'evidence/crashlytics/crashlytics_crash_keys.jpg',
      'evidence/crashlytics/crashlytics_crash_user.jpg',
    ],
    'Remote Config': ['evidence/remote_config/app_before.png', 'evidence/remote_config/console_published.jpg', 'evidence/remote_config/app_after.png'],
  };
  // One finding per line, written by hand from docs/test-plan.md section 4 after the session has really been run.
  final exploratory = File('e2e_test/exploratory/summary.txt');
  final exploratoryLines = exploratory.existsSync()
      ? exploratory.readAsLinesSync().map((l) => l.replaceFirst(RegExp(r'^[-•]\s*'), '').trim()).where((l) => l.isNotEmpty).toList()
      : <String>[];

  // ---------------------------------------------------------------- building blocks
  pw.TextStyle t(double size, {PdfColor? color, pw.Font? font, double? spacing, double? height}) =>
      pw.TextStyle(fontSize: size, color: color ?? ink, font: font ?? regular, letterSpacing: spacing, lineSpacing: height);

  pw.Widget icon(int code, {double size = 16, PdfColor? color}) =>
      icons == null ? pw.SizedBox(width: size, height: size) : pw.Icon(pw.IconData(code), size: size, color: color ?? green);

  pw.Widget iconBubble(int code, {PdfColor? color, PdfColor? bg, double size = 34}) => pw.Container(
        width: size,
        height: size,
        alignment: pw.Alignment.center,
        decoration: pw.BoxDecoration(color: bg ?? green100, shape: pw.BoxShape.circle),
        child: icon(code, size: size * 0.52, color: color ?? green),
      );

  pw.Widget chip(String text, {PdfColor? bg, PdfColor? fg, int? iconCode, double size = 9}) => pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: pw.BoxDecoration(color: bg ?? green100, borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8))),
        child: pw.Row(mainAxisSize: pw.MainAxisSize.min, children: [
          if (iconCode != null) ...[icon(iconCode, size: size + 2, color: fg ?? green800), pw.SizedBox(width: 4)],
          pw.Text(text, style: t(size, color: fg ?? green800, font: semibold)),
        ]),
      );

  pw.Widget statusChip(bool ok) =>
      ok ? chip('ĐÃ XÁC MINH', iconCode: iCheck, size: 8) : chip('CHƯA CHỤP', bg: line, fg: muted, iconCode: iSchedule, size: 8);

  // The pdf package draws a box shadow as a rectangle, which shows behind rounded corners: no shadows.
  const cardShadow = <pw.BoxShadow>[];

  pw.Widget card({required pw.Widget child, PdfColor? color, double padding = 14, PdfColor? border}) => pw.Container(
        padding: pw.EdgeInsets.all(padding),
        decoration: pw.BoxDecoration(
          color: color ?? PdfColors.white,
          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(14)),
          border: pw.Border.all(color: border ?? line, width: 0.8),
          boxShadow: cardShadow,
        ),
        child: child,
      );

  pw.Widget point(int code, String title, String body, {PdfColor? color, PdfColor? bg, bool big = false}) => pw.Padding(
        padding: pw.EdgeInsets.only(bottom: big ? 22 : 10),
        child: pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          iconBubble(code, color: color, bg: bg, size: big ? 42 : 28),
          pw.SizedBox(width: big ? 14 : 10),
          pw.Expanded(
            child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
              pw.Text(title, style: t(big ? 16 : 12, font: semibold)),
              pw.SizedBox(height: 2),
              pw.Text(body, style: t(big ? 12 : 10, color: muted)),
            ]),
          ),
        ]),
      );

  pw.Widget missing(String path, double w, double h) => pw.Container(
        width: w,
        height: h,
        alignment: pw.Alignment.center,
        color: red100,
        child: pw.Text('missing\n$path', textAlign: pw.TextAlign.center, style: t(7, color: red)),
      );

  /// A phone mockup around an app screenshot (1080 x 2400).
  pw.Widget phone(String path, {double h = 300, String? label, PdfColor? labelColor}) {
    final w = h * 0.45;
    final f = File(path);
    return pw.Column(mainAxisSize: pw.MainAxisSize.min, children: [
      pw.Container(
        padding: const pw.EdgeInsets.all(4),
        decoration: pw.BoxDecoration(
          color: PdfColor.fromHex('#111827'),
          borderRadius: pw.BorderRadius.all(pw.Radius.circular(h * 0.06)),
          boxShadow: cardShadow,
        ),
        child: pw.ClipRRect(
          horizontalRadius: h * 0.05,
          verticalRadius: h * 0.05,
          child: f.existsSync() ? pw.Image(pw.MemoryImage(f.readAsBytesSync()), width: w, height: h, fit: pw.BoxFit.cover) : missing(path, w, h),
        ),
      ),
      if (label != null) ...[
        pw.SizedBox(height: 7),
        chip(label, bg: labelColor == null ? green100 : orange100, fg: labelColor ?? green800, size: 8.5),
      ],
    ]);
  }

  /// A console screenshot inside a browser window frame.
  pw.Widget browser(String path, {required double w, double? h, String? caption}) {
    final f = File(path);
    return pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, mainAxisSize: pw.MainAxisSize.min, children: [
      pw.Container(
        width: w,
        decoration: pw.BoxDecoration(
          color: PdfColors.white,
          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(10)),
          border: pw.Border.all(color: line),
          boxShadow: cardShadow,
        ),
        child: pw.Column(children: [
          pw.Container(
            height: 16,
            padding: const pw.EdgeInsets.symmetric(horizontal: 8),
            decoration: pw.BoxDecoration(
              color: PdfColor.fromHex('#EEF0F2'),
              borderRadius: const pw.BorderRadius.vertical(top: pw.Radius.circular(10)),
            ),
            child: pw.Row(children: [
              for (final c in ['#F87171', '#FBBF24', '#34D399']) ...[
                pw.Container(width: 6, height: 6, decoration: pw.BoxDecoration(color: PdfColor.fromHex(c), shape: pw.BoxShape.circle)),
                pw.SizedBox(width: 4),
              ],
              pw.SizedBox(width: 6),
              pw.Text('console.firebase.google.com', style: t(6.5, color: muted)),
            ]),
          ),
          f.existsSync()
              ? pw.Image(pw.MemoryImage(f.readAsBytesSync()), width: w, height: h, fit: h == null ? pw.BoxFit.fitWidth : pw.BoxFit.cover, alignment: pw.Alignment.topCenter)
              : missing(path, w, h ?? w * 0.6),
        ]),
      ),
      if (caption != null) ...[pw.SizedBox(height: 5), pw.Text(caption, style: t(8.5, color: muted))],
    ]);
  }

  pw.Widget stat(String value, String label, {PdfColor? color, double size = 34}) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        mainAxisSize: pw.MainAxisSize.min,
        children: [
          pw.Text(value, style: t(size, color: color ?? green, font: bold)),
          pw.Text(label, style: t(9.5, color: muted)),
        ],
      );

  pw.Widget arrow({double size = 22, PdfColor? color}) => icon(iEast, size: size, color: color ?? orange);

  pw.Widget circle(double d, PdfColor c, double opacity) => pw.Opacity(
        opacity: opacity,
        child: pw.Container(width: d, height: d, decoration: pw.BoxDecoration(color: c, shape: pw.BoxShape.circle)),
      );

  // ---------------------------------------------------------------- slide frames
  final slides = <pw.Widget Function(int number, int count)>[];

  void content(String kicker, String title, pw.Widget Function() body) {
    slides.add((n, count) => pw.Stack(children: [
          pw.Positioned.fill(child: pw.Container(color: paper)),
          pw.Positioned(right: -110, top: -150, child: circle(330, green100, 0.7)),
          pw.Positioned(left: -70, bottom: -90, child: circle(190, orange100, 0.7)),
          pw.Positioned.fill(
            child: pw.Padding(
              padding: const pw.EdgeInsets.fromLTRB(46, 30, 46, 40),
              child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                pw.Row(children: [
                  pw.Container(
                    width: 6,
                    height: 42,
                    decoration: pw.BoxDecoration(color: green, borderRadius: const pw.BorderRadius.all(pw.Radius.circular(3))),
                  ),
                  pw.SizedBox(width: 12),
                  pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                    pw.Text(kicker.toUpperCase(), style: t(9, color: orange, font: semibold, spacing: 1.6)),
                    pw.Text(title, style: t(25, font: bold)),
                  ]),
                ]),
                pw.SizedBox(height: 16),
                pw.Expanded(child: body()),
              ]),
            ),
          ),
          pw.Positioned(
            left: 46,
            right: 46,
            bottom: 14,
            child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
              pw.Text('EXEMatching  ·  PRM393 Lab 3  ·  DEVORGANIZE222', style: t(7.5, color: muted)),
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                decoration: pw.BoxDecoration(color: green, borderRadius: const pw.BorderRadius.all(pw.Radius.circular(7))),
                child: pw.Text('${n.toString().padLeft(2, '0')} / $count', style: t(7.5, color: PdfColors.white, font: semibold)),
              ),
            ]),
          ),
        ]));
  }

  void dark(pw.Widget Function() body) {
    slides.add((n, count) => pw.Stack(children: [
          pw.Positioned.fill(
            child: pw.Container(
              decoration: pw.BoxDecoration(
                gradient: pw.LinearGradient(colors: [green900, green800, green], begin: pw.Alignment.topLeft, end: pw.Alignment.bottomRight),
              ),
            ),
          ),
          pw.Positioned(right: -120, bottom: -160, child: circle(420, PdfColors.white, 0.06)),
          pw.Positioned(left: 300, top: -120, child: circle(240, PdfColors.white, 0.05)),
          pw.Positioned.fill(child: body()),
        ]));
  }

  final mint = PdfColor.fromHex('#86EFAC');
  final mintText = PdfColor.fromHex('#D1FAE5');

  // ================================================================= 1 · cover
  dark(() => pw.Padding(
        padding: const pw.EdgeInsets.fromLTRB(56, 46, 40, 40),
        child: pw.Row(children: [
          pw.Expanded(
            flex: 11,
            child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
              pw.Row(children: [
                if (File('assets/brand/logo.png').existsSync())
                  pw.Container(
                    width: 40,
                    height: 40,
                    padding: const pw.EdgeInsets.all(5),
                    decoration: pw.BoxDecoration(color: PdfColors.white, borderRadius: const pw.BorderRadius.all(pw.Radius.circular(10))),
                    child: pw.Image(pw.MemoryImage(File('assets/brand/logo.png').readAsBytesSync())),
                  ),
                pw.SizedBox(width: 10),
                pw.Text('EXEMatching', style: t(16, color: PdfColors.white, font: semibold)),
              ]),
              pw.Spacer(),
              pw.Text('PRM393 · LẬP TRÌNH DI ĐỘNG · LAB 3', style: t(10, color: mint, font: semibold, spacing: 2)),
              pw.SizedBox(height: 10),
              pw.Text('Tìm nhóm đồ án.\nBầu trưởng nhóm.\nChốt danh sách.', style: t(34, color: PdfColors.white, font: bold, height: 2)),
              pw.SizedBox(height: 14),
              pw.Text('Ứng dụng Flutter chạy trên Firebase, kiểm thử end-to-end\ntrên máy ảo thật bằng Google ARTEMIS.',
                  style: t(13, color: mintText, font: light, height: 3)),
              pw.SizedBox(height: 22),
              pw.Wrap(spacing: 8, runSpacing: 8, children: [
                for (final s in ['Flutter · MVVM', '7 dịch vụ Firebase', '13 ca E2E × 3 lần chạy', 'Review code bằng Gemini'])
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(horizontal: 11, vertical: 5),
                    decoration: pw.BoxDecoration(
                      color: green800,
                      border: pw.Border.all(color: mint, width: 0.7),
                      borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
                    ),
                    child: pw.Text(s, style: t(9.5, color: PdfColors.white, font: semibold)),
                  ),
              ]),
              pw.Spacer(),
              pw.Text('Nhóm DEVORGANIZE222  ·  Dự án Firebase prm393-lab-3-exematching', style: t(9, color: PdfColor.fromHex('#A7F3D0'))),
            ]),
          ),
          pw.SizedBox(
            width: 380,
            height: 454,
            child: pw.Stack(overflow: pw.Overflow.visible, children: [
              pw.Positioned(left: 0, top: 90, child: pw.Transform.rotate(angle: 0.12, child: phone('docs/screenshots/scr03_browse.png', h: 290))),
              pw.Positioned(right: 0, top: 80, child: pw.Transform.rotate(angle: -0.12, child: phone('docs/screenshots/scr07_pool_member_joined.png', h: 290))),
              pw.Positioned(left: 104, top: 20, child: phone('docs/screenshots/scr02_home.png', h: 380)),
            ]),
          ),
        ]),
      ));

  // ================================================================= 2 · problem & persona
  content('Nhắc lại Lab 2', 'Chúng tôi làm app cho ai', () => pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        pw.SizedBox(
          width: 300,
          child: card(
            padding: 20,
            child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
              pw.Row(children: [
                pw.ClipOval(
                  child: File('assets/images/persona_minh.jpg').existsSync()
                      ? pw.Image(pw.MemoryImage(File('assets/images/persona_minh.jpg').readAsBytesSync()), width: 74, height: 74, fit: pw.BoxFit.cover)
                      : pw.Container(width: 74, height: 74, color: green100),
                ),
                pw.SizedBox(width: 14),
                pw.Expanded(
                  child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                    pw.Text('Minh Lê', style: t(18, font: bold)),
                    pw.Text('Sinh viên Kỹ thuật phần mềm năm cuối', style: t(10, color: muted)),
                    pw.SizedBox(height: 5),
                    chip('Persona · Lab 2', bg: orange100, fg: orange, size: 8),
                  ]),
                ),
              ]),
              pw.SizedBox(height: 16),
              icon(iQuote, size: 26, color: green),
              pw.Text(
                'Mình chỉ còn hai tuần để đăng ký nhóm đồ án. Mình không biết ai có kỹ năng nhóm cần, '
                'không ai muốn nhận làm trưởng nhóm, và chỉ cần một người rút là nhóm không chốt được.',
                style: t(13, font: italic ?? regular, height: 3),
              ),
              pw.Spacer(),
              pw.Text('MỤC TIÊU', style: t(9, font: semibold, color: muted, spacing: 1.4)),
              pw.SizedBox(height: 8),
              pw.Wrap(spacing: 6, runSpacing: 6, children: [
                chip('Đồng đội đúng kỹ năng', iconCode: iGroups),
                chip('Bầu trưởng nhóm công bằng', iconCode: iVote, bg: orange100, fg: orange),
                chip('Chốt nhóm trước hạn', iconCode: iLock, bg: blue100, fg: blue),
              ]),
            ]),
          ),
        ),
        pw.SizedBox(width: 26),
        pw.Expanded(
          child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.Text('BA NỖI LO, BA LUỒNG', style: t(10, font: semibold, color: muted, spacing: 1.4)),
            pw.SizedBox(height: 16),
            point(iSearch, 'Tìm đồng đội có đúng kỹ năng', 'Lọc nhóm còn chỗ theo chủ đề, kỹ năng, vị trí trống và tham gia chỉ với hai lần chạm.', big: true),
            point(iVote, 'Bầu trưởng nhóm không bị áp lực', 'Kết quả bị ẩn đến khi bạn bỏ phiếu; đa số phiếu chọn ra trưởng nhóm.',
                color: orange, bg: orange100, big: true),
            point(iGroupAdd, 'Gỡ rối khi có thành viên rút', 'Nhóm dưới 4 người mời sinh viên từ Waiting Pool, rồi chốt danh sách.',
                color: blue, bg: blue100, big: true),
            pw.Spacer(),
            pw.Container(
              padding: const pw.EdgeInsets.all(14),
              decoration: pw.BoxDecoration(color: green, borderRadius: const pw.BorderRadius.all(pw.Radius.circular(12))),
              child: pw.Row(children: [
                icon(iTrophy, size: 22, color: PdfColors.white),
                pw.SizedBox(width: 10),
                pw.Expanded(
                  child: pw.Text('Thành công = nhóm 4–5 người đã chốt, có trưởng nhóm được bầu, trước hạn chót.',
                      style: t(12, color: PdfColors.white, font: semibold)),
                ),
              ]),
            ),
          ]),
        ),
      ]));

  // ================================================================= 3 · three flows
  pw.Widget flow(String n, String title, String shot, String route, String alt, PdfColor c, PdfColor bg) => pw.Expanded(
        child: card(
          padding: 12,
          child: pw.Column(children: [
            pw.Row(children: [
              pw.Container(
                width: 26,
                height: 26,
                alignment: pw.Alignment.center,
                decoration: pw.BoxDecoration(color: c, shape: pw.BoxShape.circle),
                child: pw.Text(n, style: t(13, color: PdfColors.white, font: bold)),
              ),
              pw.SizedBox(width: 8),
              pw.Text(title, style: t(14, font: bold)),
            ]),
            pw.SizedBox(height: 8),
            phone(shot, h: 238),
            pw.SizedBox(height: 8),
            pw.Text(route, textAlign: pw.TextAlign.center, style: t(9, font: semibold, color: c)),
            pw.SizedBox(height: 3),
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: pw.BoxDecoration(color: bg, borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8))),
              child: pw.Text(alt, textAlign: pw.TextAlign.center, style: t(8.5)),
            ),
          ]),
        ),
      );
  content('3 luồng chính', 'Từ tìm nhóm đến chốt danh sách', () => pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        flow('1', 'Tìm & tham gia', 'docs/screenshots/scr04_join_dialog.png', 'Home → Browse → Chi tiết nhóm → Join',
            'Nhánh phụ: nhóm vừa đầy · không có kết quả · mất mạng', green, green100),
        pw.SizedBox(width: 16),
        flow('2', 'Bầu trưởng nhóm', 'docs/screenshots/scr06_voting_elected.png', 'My Team → Vote → đa số thắng',
            'Nhánh phụ: ẩn kết quả đến khi bỏ phiếu · đổi phiếu', orange, orange100),
        pw.SizedBox(width: 16),
        flow('3', 'Chốt danh sách', 'docs/screenshots/scr07_pool_member_joined.png', 'Review & Lock → Waiting Pool → Lock',
            'Nhánh phụ: dưới 4 người thì không chốt được', blue, blue100),
      ]));

  // ================================================================= 4 · Figma → app
  pw.Widget pair(String figma, String app, String label) => pw.Column(children: [
        pw.Row(mainAxisSize: pw.MainAxisSize.min, children: [
          phone(figma, h: 250, label: 'Figma'),
          pw.Padding(padding: const pw.EdgeInsets.symmetric(horizontal: 6), child: arrow(size: 18)),
          phone(app, h: 250, label: 'App', labelColor: orange),
        ]),
        pw.SizedBox(height: 6),
        pw.Text(label, style: t(10, font: semibold)),
      ]);
  content('Truy vết thiết kế', 'Từ khung Figma đến Flutter', () => pw.Column(children: [
        pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
          pair('assets/figma/SCR_02_ Dashboard.png', 'docs/screenshots/scr02_home.png', 'SCR_02 · Home'),
          pair('assets/figma/SCR_03_ Browse Groups.png', 'docs/screenshots/scr03_browse.png', 'SCR_03 · Browse'),
          pair('assets/figma/SCR_07_ Group Lock Review & Error Recovery.png', 'docs/screenshots/scr07_lock_error.png', 'SCR_07 · Review & Lock'),
        ]),
        pw.Spacer(),
        pw.Row(children: [
          pw.Text('Khác biệt có chủ đích  ', style: t(10, font: semibold, color: muted)),
          pw.Expanded(
            child: pw.Wrap(spacing: 6, runSpacing: 6, children: [
              chip('DV-01 Dùng “Team” thống nhất'),
              chip('DV-04 Tham gia trực tiếp'),
              chip('DV-08 Chuông + tab Settings'),
              chip('DV-09/10 Tương phản WCAG AA'),
              chip('DV-14 Icon + chữ, không chỉ dùng màu'),
              chip('16 mục trong docs/design-traceability.md', bg: orange100, fg: orange),
            ]),
          ),
        ]),
      ]));

  // ================================================================= 5 · architecture
  pw.Widget layer(int code, String name, String path, String role, PdfColor c, PdfColor bg) => pw.Expanded(
        child: pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: pw.BoxDecoration(
          color: PdfColors.white,
          border: pw.Border.all(color: line, width: 0.8),
          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(10)),
          boxShadow: cardShadow,
        ),
        child: pw.Row(children: [
          pw.Container(width: 4, height: 46, decoration: pw.BoxDecoration(color: c, borderRadius: const pw.BorderRadius.all(pw.Radius.circular(2)))),
          pw.SizedBox(width: 12),
          iconBubble(code, color: c, bg: bg, size: 40),
          pw.SizedBox(width: 14),
          pw.Expanded(
            child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, mainAxisAlignment: pw.MainAxisAlignment.center, children: [
              pw.Row(children: [pw.Text(name, style: t(15, font: semibold)), pw.SizedBox(width: 8), pw.Text(path, style: t(9.5, color: muted))]),
              pw.SizedBox(height: 2),
              pw.Text(role, style: t(11, color: muted)),
            ]),
          ),
        ]),
      ),
      );
  pw.Widget down() => pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 2),
        child: pw.Center(child: pw.Transform.rotate(angle: -1.5708, child: icon(iEast, size: 16, color: muted))),
      );
  content('Kiến trúc', 'MVVM, phụ thuộc một chiều', () => pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        pw.Expanded(
          flex: 3,
          child: pw.Column(children: [
            layer(iPalette, 'Màn hình & widget', 'lib/screens · lib/widgets', 'Chỉ UI khai báo: không Firebase SDK, không logic nghiệp vụ', green, green100),
            down(),
            layer(iTune, 'ViewModels', 'lib/viewmodels', 'ChangeNotifier giữ ViewState<T>, kiểm tra dữ liệu và gọi analytics', orange, orange100),
            down(),
            layer(iTree, 'Interface dịch vụ', 'lib/services', 'Hợp đồng mà view-model phụ thuộc; bản giả lập để test', blue, blue100),
            down(),
            layer(iCloud, 'Cài đặt Firebase', 'lib/firebase', 'Auth, Firestore, Storage, FCM, Analytics, Crashlytics, Remote Config', green800, green100),
          ]),
        ),
        pw.SizedBox(width: 24),
        pw.Expanded(
          flex: 2,
          child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            card(
              child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                pw.Text('Mỗi màn hình hiển thị một ViewState<T>', style: t(12, font: semibold)),
                pw.SizedBox(height: 8),
                pw.Wrap(spacing: 6, runSpacing: 6, children: [
                  chip('Loading', bg: blue100, fg: blue),
                  chip('Rỗng + hành động', bg: orange100, fg: orange),
                  chip('Lỗi + thử lại', bg: red100, fg: red),
                  chip('Dữ liệu'),
                ]),
              ]),
            ),
            pw.SizedBox(height: 14),
            card(
              child: pw.Row(children: [
                stat('$uiFirebaseImports', 'import Firebase trong\nlib/screens + lib/widgets', color: uiFirebaseImports == 0 ? green : red, size: 40),
                pw.SizedBox(width: 18),
                pw.Expanded(child: pw.Text('Đếm từ mã nguồn mỗi khi tạo slide.', style: t(9.5, color: muted))),
              ]),
            ),
            pw.SizedBox(height: 14),
            pw.Expanded(
              child: card(child: point(iKey, 'Một điểm khởi tạo duy nhất', 'lib/app/providers.dart nối các dịch vụ Firebase vào view-model bằng Provider.', big: true)),
            ),
          ]),
        ),
      ]));

  // ================================================================= 6 · Firebase map
  pw.Widget service(int code, String name, String what, String proof) => pw.Expanded(
        child: card(
          padding: 14,
          child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [iconBubble(code, size: 40), statusChip(captured(evidence[name]!))]),
            pw.SizedBox(height: 12),
            pw.Text(name, style: t(15, font: bold)),
            pw.SizedBox(height: 4),
            pw.Text(what, style: t(10.5, color: muted)),
            pw.Spacer(),
            pw.Divider(color: line, height: 10),
            pw.Text(proof, style: t(8.5, color: green800)),
          ]),
        ),
      );
  content('Backend đám mây', '7 dịch vụ Firebase, đều có bằng chứng console', () => pw.Column(children: [
        pw.Expanded(
          child: pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.stretch, children: [
            service(iLogin, 'Authentication', 'Đăng nhập Google, chỉ cho sinh viên trong danh sách lớp', 'Tab Users · chặn ngoài danh sách (TC-01)'),
            pw.SizedBox(width: 12),
            service(iStorage, 'Firestore', 'Nhóm, phiếu bầu và Waiting Pool trong transaction', 'Document nhóm · rules đã deploy'),
            pw.SizedBox(width: 12),
            service(iUpload, 'Storage', 'PDF của nhóm tải lên reports/{uid}/', 'PDF đã tải · rules chỉ chủ sở hữu'),
            pw.SizedBox(width: 12),
            service(iBell, 'Cloud Messaging', 'Lời mời và cập nhật ở cả 3 trạng thái app', 'Foreground · background · terminated'),
          ]),
        ),
        pw.SizedBox(height: 12),
        pw.Expanded(
          child: pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.stretch, children: [
          service(iInsights, 'Analytics', '10 sự kiện, chỉ gửi ID và số đếm', 'DebugView · Logcat mỗi lần chạy E2E'),
          pw.SizedBox(width: 12),
          service(iBug, 'Crashlytics', 'Crash và lỗi non-fatal kèm user ID và key', 'Test crash + non-fatal, 04/11'),
          pw.SizedBox(width: 12),
          service(iTune, 'Remote Config', 'Bật/tắt đăng ký và pool tức thì', 'Đã publish, thấy ngay, đã hoàn tác'),
          pw.SizedBox(width: 12),
          pw.Expanded(
            child: pw.Container(
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(color: green, borderRadius: const pw.BorderRadius.all(pw.Radius.circular(14))),
              child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                icon(iShield, size: 26, color: PdfColors.white),
                pw.SizedBox(height: 8),
                pw.Text('Security rules', style: t(13, color: PdfColors.white, font: bold)),
                pw.Text('Rules của Firestore và Storage, đã deploy và chụp lại từ console.', style: t(10.5, color: green100)),
              ]),
            ),
          ),
        ]),
        ),
        pw.SizedBox(height: 10),
        pw.Text('ĐÃ XÁC MINH nghĩa là ảnh chụp console hoặc thiết bị có trong evidence/ lúc tạo slide.', style: t(9, color: muted)),
      ]));

  // ================================================================= 7 · Auth
  final tc01 = finalRuns['TC-01'];
  content('Dịch vụ 1 · Authentication', 'Đăng nhập Google, chỉ danh sách lớp', () => pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        phone('docs/screenshots/scr01_sign_in.png', h: 330),
        pw.SizedBox(width: 12),
        phone('docs/screenshots/scr01_account_picker.png', h: 330),
        pw.SizedBox(width: 24),
        pw.Expanded(
          child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            browser('evidence/console/console_auth_users.jpg', w: 380, h: 150, caption: 'Authentication → Users: tài khoản Google kèm UID'),
            pw.SizedBox(height: 14),
            point(iLogin, 'Google credential → FirebaseAuth', 'authStateChanges() điều hướng màn hình; đăng xuất xóa cả phiên Google và Firebase.'),
            point(iShield, 'Kiểm tra danh sách ở app và rules', 'allowedEmails/{email} phải được bật; rules kiểm tra isRosterMember().', color: orange, bg: orange100),
            point(iCancel, 'Không có trong danh sách? Từ chối',
                tc01 == null ? 'Được kiểm bởi E2E TC-01.' : 'E2E TC-01 đạt ${tc01.where((r) => r).length}/${tc01.length} lần chạy.', color: red, bg: red100),
          ]),
        ),
      ]));

  // ================================================================= 8 · Firestore
  content('Dịch vụ 2 · Cloud Firestore', 'Transaction và security rules chặt chẽ', () => pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        browser('evidence/console/console_firestore_rules_teams.jpg', w: 470, h: 300, caption: 'Rules đã deploy: sinh viên chỉ sửa được các trường danh sách (GR-01)'),
        pw.SizedBox(width: 22),
        pw.Expanded(
          child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.Row(children: [
              pw.Expanded(child: card(child: stat('$transactions', 'thao tác chạy trong\nrunTransaction'))),
              pw.SizedBox(width: 12),
              pw.Expanded(child: card(child: stat('$writableFields', 'trường sinh viên\nđược sửa', color: orange))),
            ]),
            pw.SizedBox(height: 14),
            point(iGroups, 'Join, rời nhóm, bầu, chốt, mời', 'Mỗi thao tác đọc lại nhóm trong transaction, nên hai sinh viên không thể cùng lấy chỗ cuối.'),
            point(iLock, 'affectedKeys().hasOnly([...])', 'Client không thể sửa chủ đề, sĩ số hay giảng viên hướng dẫn.', color: orange, bg: orange100),
            point(iHidden, 'Quyền riêng tư Waiting Pool', 'Trưởng nhóm chỉ đọc được ứng viên chưa xếp nhóm; hồ sơ đã xếp được giữ riêng tư.', color: blue, bg: blue100),
          ]),
        ),
      ]));

  // ================================================================= 9 · Storage
  content('Dịch vụ 3 · Cloud Storage', 'PDF nhóm, chỉ chủ sở hữu truy cập', () => pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        phone('docs/screenshots/profile_export_done.png', h: 330, label: 'Export & Upload'),
        pw.SizedBox(width: 26),
        pw.Expanded(
          child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            browser('evidence/console/console_storage_files.jpg', w: 520, h: 170, caption: 'Storage → reports/{uid}/: PDF do app tải lên (E2E TC-13)'),
            pw.SizedBox(height: 14),
            pw.Container(
              width: 520,
              padding: const pw.EdgeInsets.all(14),
              decoration: pw.BoxDecoration(color: PdfColor.fromHex('#0F172A'), borderRadius: const pw.BorderRadius.all(pw.Radius.circular(10))),
              child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                pw.Text('firebase/storage.rules', style: t(8, color: PdfColor.fromHex('#94A3B8'))),
                pw.SizedBox(height: 4),
                pw.Text(
                  'match /reports/{userId}/{allPaths=**} {\n  allow read, write: if request.auth != null\n                     && request.auth.uid == userId;\n}',
                  style: pw.TextStyle(font: pw.Font.courier(), fontSize: 10, color: PdfColor.fromHex('#A7F3D0'), lineSpacing: 2),
                ),
              ]),
            ),
            pw.SizedBox(height: 12),
            pw.Row(children: [
              chip('PDF tạo ngay trên máy', iconCode: iPdf),
              pw.SizedBox(width: 6),
              chip('Tiến độ tải 0 → 100 %', iconCode: iUpload),
              pw.SizedBox(width: 6),
              chip('Hiện link tải về', iconCode: iCheck),
            ]),
          ]),
        ),
      ]));

  // ================================================================= 10 · FCM
  pw.Widget fcmState(String state, String path, String how, PdfColor c) => pw.Column(children: [
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          decoration: pw.BoxDecoration(color: c, borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8))),
          child: pw.Text(state, style: t(11, color: PdfColors.white, font: bold)),
        ),
        pw.SizedBox(height: 8),
        phone(path, h: 290),
        pw.SizedBox(height: 8),
        pw.SizedBox(width: 200, child: pw.Text(how, textAlign: pw.TextAlign.center, style: t(9.5, color: muted))),
      ]);
  content('Dịch vụ 4 · Cloud Messaging', 'Một tin nhắn thử, ba trạng thái app', () => pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceEvenly,
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          fcmState('Foreground', 'evidence/fcm/foreground_alerts.png', 'onMessage lưu lại; hiện ngay trong Alerts', green),
          pw.Padding(padding: const pw.EdgeInsets.only(top: 160), child: arrow()),
          fcmState('Background', 'evidence/fcm/background.png', 'Android hiện thông báo; chạm vào chạy onMessageOpenedApp', orange),
          pw.Padding(padding: const pw.EdgeInsets.only(top: 160), child: arrow()),
          fcmState('Terminated', 'evidence/fcm/terminated_opened.png', 'App đã tắt hẳn; chạm vào mở app thẳng tới nhóm', blue),
        ],
      ));

  // ================================================================= 11 · Analytics
  content('Dịch vụ 5 · Google Analytics', '10 sự kiện, không có dữ liệu cá nhân', () => pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        pw.Expanded(
          flex: 4,
          child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.Text('Sự kiện khuyến nghị', style: t(11, font: semibold, color: muted)),
            pw.SizedBox(height: 6),
            pw.Wrap(spacing: 6, runSpacing: 6, children: [for (final e in ['login', 'logout', 'search_teams', 'view_team']) chip(e, iconCode: iInsights)]),
            pw.SizedBox(height: 12),
            pw.Text('Sự kiện nghiệp vụ', style: t(11, font: semibold, color: muted)),
            pw.SizedBox(height: 6),
            pw.Wrap(spacing: 6, runSpacing: 6, children: [
              for (final e in ['create_team', 'join_team', 'cast_vote', 'invite_pool', 'lock_roster', 'export_report'])
                chip(e, bg: orange100, fg: orange, iconCode: iBolt),
            ]),
            pw.SizedBox(height: 18),
            point(iHidden, 'Chỉ ID và số đếm', 'search_teams gửi query_length, không gửi từ khóa; không email, không tên.'),
            point(iPerson, 'User ID sau khi đăng nhập', 'setUserId(uid) gắn sự kiện với tài khoản, không gắn với tên.', color: orange, bg: orange100),
            point(iFact, 'Kiểm tra hai lần', 'Ảnh DebugView, và mỗi lần chạy E2E lưu lại các sự kiện từ Logcat.', color: blue, bg: blue100),
          ]),
        ),
        pw.SizedBox(width: 22),
        pw.Expanded(
          flex: 5,
          child: browser('evidence/debugview/debugview_search_teams_params.jpg', w: 470, caption: 'DebugView: search_teams với query_length, result_count và filter_count'),
        ),
      ]));

  // ================================================================= 12 · Crashlytics
  content('Dịch vụ 6 · Crashlytics', 'Crash và lỗi đã xử lý, kèm ngữ cảnh', () => pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        phone('docs/screenshots/profile_non_fatal_sent.png', h: 330, label: 'Send Test Error'),
        pw.SizedBox(width: 24),
        pw.Expanded(
          child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            browser('evidence/crashlytics/crashlytics_crash_keys.jpg', w: 520, h: 150, caption: 'Test crash lúc 06:51:57 ngày 04/11 · Keys: screen = profile'),
            pw.SizedBox(height: 10),
            browser('evidence/crashlytics/crashlytics_crash_user.jpg', w: 520, h: 95, caption: 'Cùng sự kiện · Data: user ID là UID của Firebase Auth'),
            pw.SizedBox(height: 10),
            pw.Wrap(spacing: 6, runSpacing: 6, children: [
              chip('FlutterError.onError → fatal', iconCode: iBug, bg: red100, fg: red),
              chip('recordError → non-fatal', iconCode: iWarn, bg: orange100, fg: orange),
              chip('keys: screen · student_cohort · team_id', iconCode: iKey),
            ]),
          ]),
        ),
      ]));

  // ================================================================= 13 · Remote Config
  content('Dịch vụ 7 · Remote Config', 'Đóng đăng ký mà không cần cập nhật app', () => pw.Column(children: [
        pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
          phone('evidence/remote_config/app_before.png', h: 290, label: 'Trước · false'),
          arrow(),
          browser('evidence/remote_config/console_published.jpg', w: 260, h: 185, caption: 'registration_closed = true, đã publish'),
          arrow(),
          phone('evidence/remote_config/app_after.png', h: 290, label: 'Sau · true', labelColor: orange),
          phone('evidence/remote_config/app_after_home.png', h: 290, label: 'Home: đã đóng', labelColor: orange),
        ]),
        pw.Spacer(),
        pw.Container(
          padding: const pw.EdgeInsets.all(12),
          decoration: pw.BoxDecoration(
            color: PdfColors.white,
            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(12)),
            border: pw.Border.all(color: line),
          ),
          child: pw.Row(children: [
            icon(iSync, size: 20),
            pw.SizedBox(width: 10),
            pw.Expanded(
              child: pw.Text(
                'onConfigUpdated kích hoạt giá trị mới và view-model dựng lại giao diện: app đang mở đổi trong vòng một phút, '
                'không cần khởi động lại hay cài lại. Sau đó tham số đã được xóa.',
                style: t(10.5),
              ),
            ),
          ]),
        ),
      ]));

  // ================================================================= 14 · ARTEMIS E2E
  pw.Widget dot(bool? ok) => pw.Container(
        width: 13,
        height: 13,
        margin: const pw.EdgeInsets.symmetric(horizontal: 2),
        alignment: pw.Alignment.center,
        decoration: pw.BoxDecoration(color: ok == null ? line : (ok ? green : red), shape: pw.BoxShape.circle),
        child: ok == null ? null : icon(ok ? iCheck : iCancel, size: 9, color: PdfColors.white),
      );
  const caseNames = {
    'TC-01': 'Tài khoản ngoài danh sách',
    'TC-02': 'Đăng nhập tài khoản hợp lệ',
    'TC-03': 'Tìm kiếm & lọc',
    'TC-04': 'Không có kết quả + xóa bộ lọc',
    'TC-05': 'Mất mạng + thử lại',
    'TC-06': 'Tham gia nhóm còn chỗ',
    'TC-07': 'Nhóm đầy trước khi xác nhận',
    'TC-08': 'Ẩn kết quả đến khi bỏ phiếu',
    'TC-09': 'Bỏ phiếu chọn trưởng nhóm',
    'TC-10': 'Không chốt được → mời từ pool',
    'TC-11': 'Chia sẻ link → share sheet Android',
    'TC-12': 'Từ chối lời mời + Hoàn tác',
    'TC-13': 'Xuất & tải lên PDF nhóm',
  };
  content('Chất lượng · Google ARTEMIS', '13 ca × 3 lần chạy trên máy ảo thật', () => pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        pw.Expanded(
          flex: 4,
          child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            card(
              child: pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
                pw.Text(total == 0 ? '–' : '$passed', style: t(50, font: bold, color: green)),
                pw.Padding(padding: const pw.EdgeInsets.only(bottom: 9), child: pw.Text(' / $total', style: t(24, font: semibold, color: muted))),
                pw.SizedBox(width: 12),
                pw.Expanded(
                  child: pw.Padding(
                    padding: const pw.EdgeInsets.only(bottom: 10),
                    child: pw.Text('lần chạy đạt ở lượt cuối\n(e2e_test/evidence/junit.xml)', style: t(9.5, color: muted)),
                  ),
                ),
              ]),
            ),
            pw.SizedBox(height: 14),
            pw.Text('Mọi lượt chạy, đúng như đã ghi', style: t(11, font: semibold, color: muted)),
            pw.SizedBox(height: 8),
            for (final (name, runs) in attempts)
              pw.Padding(
                padding: const pw.EdgeInsets.only(bottom: 7),
                child: pw.Row(children: [
                  pw.SizedBox(width: 62, child: pw.Text(name, style: t(9.5, font: semibold))),
                  pw.Container(
                    width: 220,
                    height: 14,
                    alignment: pw.Alignment.centerLeft,
                    decoration: pw.BoxDecoration(color: line, borderRadius: const pw.BorderRadius.all(pw.Radius.circular(7))),
                    child: totalOf(runs) == 0 || passedOf(runs) == 0
                        ? null
                        : pw.Container(
                            width: 220 * passedOf(runs) / totalOf(runs),
                            height: 14,
                            decoration: pw.BoxDecoration(
                              color: name == 'Lượt cuối' ? green : mint,
                              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(7)),
                            ),
                          ),
                  ),
                  pw.SizedBox(width: 8),
                  pw.Text(totalOf(runs) == 0 ? 'n/a' : '${passedOf(runs)}/${totalOf(runs)}', style: t(9.5, font: semibold)),
                ]),
              ),
            pw.SizedBox(height: 8),
            point(iRobot, 'Không tin vào SUCCESS của agent', 'Mỗi lần chạy được đối chiếu với cây accessibility, Logcat và Firestore.', color: blue, bg: blue100),
            point(iWarn, 'Lần chạy lỗi đều được giải thích', 'Bug tìm được, lỗi harness và lỗi 429 của Gemini free tier, theo từng trace ID: docs/test-plan.md §3.',
                color: orange, bg: orange100),
          ]),
        ),
        pw.SizedBox(width: 20),
        pw.Expanded(
          flex: 5,
          child: card(
            padding: 12,
            child: pw.Column(children: [
              pw.Row(children: [
                pw.Expanded(child: pw.Text('Ca kiểm thử', style: t(9, font: semibold, color: muted))),
                pw.Text('Lần 1 · 2 · 3', style: t(9, font: semibold, color: muted)),
              ]),
              pw.Divider(color: line, height: 8),
              for (final id in caseNames.keys)
                pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(vertical: 1.6),
                  child: pw.Row(children: [
                    pw.SizedBox(width: 38, child: pw.Text(id, style: t(9, font: semibold, color: green800))),
                    pw.Expanded(child: pw.Text(caseNames[id]!, style: t(9))),
                    for (var i = 0; i < 3; i++) dot((finalRuns[id]?.length ?? 0) > i ? finalRuns[id]![i] : null),
                  ]),
                ),
            ]),
          ),
        ),
      ]));

  // ================================================================= 15 · AI code review
  pw.Widget finding(String id, String cat, String text, bool accepted, String decision) => card(
        padding: 10,
        border: accepted ? mint : PdfColor.fromHex('#FCA5A5'),
        child: pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pw.SizedBox(
            width: 70,
            child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
              pw.Text(id, style: t(12, font: bold)),
              pw.Text(cat, style: t(7.5, color: muted)),
            ]),
          ),
          pw.Expanded(child: pw.Text(text, style: t(9.5))),
          pw.SizedBox(width: 8),
          pw.SizedBox(
            width: 190,
            child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
              accepted ? chip('CHẤP NHẬN', iconCode: iCheck, size: 8) : chip('BÁC BỎ', bg: red100, fg: red, iconCode: iCancel, size: 8),
              pw.SizedBox(height: 3),
              pw.Text(decision, textAlign: pw.TextAlign.right, style: t(8, color: muted)),
            ]),
          ),
        ]),
      );
  pw.Widget step() => pw.Padding(padding: const pw.EdgeInsets.symmetric(horizontal: 6), child: arrow(size: 14));
  content('Review code có AI hỗ trợ', 'Gemini review PR, con người quyết định', () => pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        pw.Row(children: [
          chip('Pull request', iconCode: iCode, bg: blue100, fg: blue),
          step(),
          chip('gemini_review.py · một lần gọi API', iconCode: iSpark, bg: orange100, fg: orange),
          step(),
          chip('gemini-3.5-flash-lite', iconCode: iRobot),
          step(),
          chip('Bình luận review theo dòng', iconCode: iFact, bg: blue100, fg: blue),
        ]),
        pw.SizedBox(height: 12),
        finding('GR-01', 'Bảo mật · Cao', 'isSelfJoin chỉ kiểm tra số thành viên, nên client có thể sửa luôn chủ đề, sĩ số hoặc giảng viên.', true,
            'Đã sửa cho cả 5 thao tác trên nhóm · c9543a3'),
        pw.SizedBox(height: 7),
        finding('GR-02', 'Đồng thời · TB', 'Truy vấn Waiting Pool ngoài transaction có thể khiến hai nhóm chọn cùng một sinh viên.', false,
            'SDK client không truy vấn được trong transaction; ứng viên đã được đọc lại bên trong'),
        pw.SizedBox(height: 7),
        finding('GR-03', 'Độ tin cậy · TB', 'Thiếu đăng nhập Firebase CLI gây KeyError khó hiểu trong backend E2E.', true, 'Thông báo hướng dẫn rõ ràng · ee6ec78'),
        pw.SizedBox(height: 7),
        finding('GR-04', 'Độ tin cậy · Thấp', 'Khối catch lúc khởi động Remote Config làm mất thông báo lỗi.', true, 'Ghi log, giữ giá trị mặc định · d6926d1'),
        pw.SizedBox(height: 7),
        finding('GR-05', 'Độ tin cậy · TB', 'Cắt nội dung lỗi còn 2000 ký tự có thể làm vỡ một ký tự UTF-8.', false, 'Báo nhầm: đã decode trước khi cắt'),
      ]));

  // ================================================================= 16 · lessons
  content('Bài học từ kiểm thử', 'Bug thật, tìm thấy trên thiết bị thật', () => pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        pw.Expanded(
          child: card(
            padding: 16,
            child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
              pw.Row(children: [icon(iBug, size: 18, color: red), pw.SizedBox(width: 6), pw.Text('Bug phát hiện khi chạy, đã sửa hết', style: t(13, font: bold))]),
              pw.SizedBox(height: 10),
              point(iGroupAdd, 'Mời từ Waiting Pool luôn thất bại', 'Rules chặn trưởng nhóm đọc hồ sơ pool chưa xếp nhóm (PERMISSION_DENIED).', color: red, bg: red100, big: true),
              point(iSearch, 'TalkBack và ARTEMIS không gõ được chữ', 'Một lớp Semantics tạo ra ô nhập thứ hai không sửa được.', color: red, bg: red100, big: true),
              point(iInsights, 'Bỏ phiếu báo lỗi sai', 'cast_vote gửi tham số bool mà Analytics từ chối.', color: red, bg: red100, big: true),
              point(iWarn, 'Nút Hoàn tác sau khi từ chối không hiện', 'Thẻ bị hủy trước khi snackbar kịp hiện.', color: red, bg: red100, big: true),
            ]),
          ),
        ),
        pw.SizedBox(width: 18),
        pw.Expanded(
          child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            card(
              padding: 16,
              child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                pw.Row(children: [icon(iBulb, size: 18, color: orange), pw.SizedBox(width: 6), pw.Text('Bài học', style: t(13, font: bold))]),
                pw.SizedBox(height: 10),
                point(iRobot, '“Thành công” của agent chưa phải bằng chứng', 'TC-12 báo đã khôi phục lời mời trong khi màn hình không còn lời mời nào.', color: orange, bg: orange100, big: true),
                point(iVerified, 'Chỉ tính lần chạy có ghi lại', 'Có trace ID, ảnh chụp và kiểm tra Firestore, không bao giờ gõ tay 39/39.', color: orange, bg: orange100, big: true),
                point(iShield, 'Test rules bằng luồng thật', 'Một rule trông đúng đã làm hỏng Flow 3, chỉ lộ ra khi chạy app thật.', color: orange, bg: orange100, big: true),
              ]),
            ),
            pw.SizedBox(height: 12),
            pw.Container(
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(color: blue100, borderRadius: const pw.BorderRadius.all(pw.Radius.circular(12))),
              child: pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                icon(iScience, size: 18, color: blue),
                pw.SizedBox(width: 8),
                pw.Expanded(
                  child: pw.Text(
                    exploratoryLines.isEmpty
                        ? 'Phiên kiểm thử khám phá ARTEMIS Pro: chưa chạy (docs/test-plan.md §4).'
                        : 'Phiên khám phá: ${exploratoryLines.join(' · ')}',
                    style: t(9.5),
                  ),
                ),
              ]),
            ),
          ]),
        ),
      ]));

  // ================================================================= 17 · thank you
  dark(() => pw.Padding(
        padding: const pw.EdgeInsets.fromLTRB(56, 46, 56, 40),
        child: pw.Row(children: [
          pw.Expanded(
            child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
              pw.Spacer(),
              pw.Text('CẢM ƠN', style: t(11, color: mint, font: semibold, spacing: 3)),
              pw.SizedBox(height: 8),
              pw.Text('Hỏi & đáp', style: t(48, color: PdfColors.white, font: bold)),
              pw.SizedBox(height: 18),
              for (final (code, text) in [
                (iCode, 'github.com/DEVORGANIZE222/Lab3_Cloud-Enabled_Mobile_App'),
                (iFact, 'docs/test-plan.md · evidence/ · report/Lab03_DEVORGANIZE222.pdf'),
                (iCloud, 'Firebase project prm393-lab-3-exematching'),
              ])
                pw.Padding(
                  padding: const pw.EdgeInsets.only(bottom: 8),
                  child: pw.Row(children: [
                    icon(code, size: 15, color: mint),
                    pw.SizedBox(width: 8),
                    pw.Text(text, style: t(11, color: mintText)),
                  ]),
                ),
              pw.Spacer(),
              pw.Text('Nhóm DEVORGANIZE222  ·  PRM393 Lập trình di động  ·  Đại học FPT', style: t(9, color: PdfColor.fromHex('#A7F3D0'))),
            ]),
          ),
          pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
            phone('docs/screenshots/scr06_voting_elected.png', h: 300),
            pw.SizedBox(width: 14),
            phone('docs/screenshots/scr07_locked.png', h: 380),
          ]),
        ]),
      ));

  // ---------------------------------------------------------------- render
  for (var i = 0; i < slides.length; i++) {
    pdf.addPage(pw.Page(
      pageFormat: const PdfPageFormat(kW, kH),
      margin: pw.EdgeInsets.zero,
      build: (context) => slides[i](i + 1, slides.length),
    ));
  }

  final out = File('slides/Final_DEVORGANIZE222_slides.pdf');
  out.parent.createSync(recursive: true);
  final Uint8List bytes = await pdf.save();
  out.writeAsBytesSync(bytes);
  File('slides/Lab03_DEVORGANIZE222_slides.pdf').writeAsBytesSync(bytes);
  // ignore: avoid_print
  print('Successfully generated Final Slides: ${out.path} (${bytes.length} bytes, ${slides.length} slides)');
}

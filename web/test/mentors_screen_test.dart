import 'dart:async';

import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:web_admin/screens/mentors_screen.dart';
import 'package:web_admin/theme/admin_theme.dart';

const thanh = Mentor(
  id: 'm_thanh',
  fullName: 'Dr. Nguyen Thanh',
  email: 'thanhnt@fpt.edu.vn',
  title: 'Head of AI Lab',
  department: 'Software Engineering',
  expertise: ['AI/ML'],
  bio: '',
  maxQuota: 2,
  currentAssigned: 1,
  mentoredTeamNames: ['Team AI-04'],
);

/// Records calls instead of writing to Firestore.
class FakeMentorAdmin extends MentorAdminService {
  FakeMentorAdmin(this.mentors, {this.requests = const []});

  List<Mentor> mentors;
  final List<MentorRequest> requests;
  final _changes = StreamController<List<Mentor>>.broadcast();
  final calls = <String>[];
  Object? failWith;

  void _emit() => _changes.add(mentors);

  @override
  Stream<List<Mentor>> watchMentors() async* {
    yield mentors;
    yield* _changes.stream;
  }

  @override
  Stream<List<MentorRequest>> watchRequests() => Stream.value(requests);

  @override
  Future<void> create(Mentor mentor) async {
    if (failWith != null) throw failWith!;
    calls.add('create ${mentor.email} ${mentor.maxQuota} ${mentor.expertise.join('|')}');
    mentors = [...mentors, mentor];
    _emit();
  }

  @override
  Future<void> update(Mentor before, Mentor after) async {
    if (failWith != null) throw failWith!;
    calls.add('update ${after.title} ${after.maxQuota}');
    mentors = [for (final m in mentors) m.id == before.id ? after : m];
    _emit();
  }

  @override
  Future<void> setArchived(Mentor mentor, bool archived) async {
    calls.add('archive ${mentor.id} $archived');
    mentors = [
      for (final m in mentors)
        m.id == mentor.id
            ? Mentor.fromJson({'id': m.id, 'fullName': m.fullName, 'status': archived ? 'archived' : 'active'})
            : m,
    ];
    _emit();
  }
}

void main() {
  Future<FakeMentorAdmin> open(WidgetTester tester, FakeMentorAdmin fake) async {
    tester.view.physicalSize = const Size(1280, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(theme: buildAdminTheme(), home: Scaffold(body: MentorsScreen(service: fake))),
    );
    await tester.pumpAndSettle();
    return fake;
  }

  Finder field(String label) => find.widgetWithText(TextFormField, label);

  testWidgets('lists lecturers, figures and requests', (tester) async {
    await open(
      tester,
      FakeMentorAdmin(
        [thanh],
        requests: [
          MentorRequest(
            teamId: 't1',
            teamName: 'Team AI-04',
            mentorId: 'm_thanh',
            mentorName: 'Dr. Nguyen Thanh',
            senderId: 's1',
            senderName: 'Minh Le',
            message: '',
            createdAt: DateTime(2026, 11, 7, 9, 30),
          ),
        ],
      ),
    );
    expect(find.text('Dr. Nguyen Thanh'), findsOneWidget);
    expect(find.text('Đang hướng dẫn 1/2 nhóm'), findsOneWidget);
    expect(find.text('Team AI-04 → Dr. Nguyen Thanh'), findsOneWidget);
    expect(find.text('Đang chờ'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('empty directory', (tester) async {
    await open(tester, FakeMentorAdmin([]));
    expect(find.textContaining('Chưa có giảng viên nào'), findsOneWidget);
    expect(find.text('Chưa có nhóm nào gửi yêu cầu.'), findsOneWidget);
  });

  testWidgets('search filters by expertise', (tester) async {
    await open(
      tester,
      FakeMentorAdmin([
        thanh,
        Mentor.fromJson({
          'id': 'm2',
          'fullName': 'Dr. B',
          'expertise': ['Mobile'],
        }),
      ]),
    );
    await tester.enterText(find.byType(TextField).first, 'mobile');
    await tester.pump();
    expect(find.text('Dr. B'), findsOneWidget);
    expect(find.text('Dr. Nguyen Thanh'), findsNothing);
  });

  testWidgets('create validates, then saves', (tester) async {
    final fake = await open(tester, FakeMentorAdmin([]));
    await tester.tap(find.text('Thêm giảng viên'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Lưu'));
    await tester.pumpAndSettle();
    expect(find.text('Không được để trống'), findsWidgets);
    expect(fake.calls, isEmpty);

    await tester.enterText(field('Họ tên'), 'Dr. Vu Quoc Anh');
    await tester.enterText(field('Email đăng nhập Google'), 'AnhVQ@fpt.edu.vn');
    await tester.enterText(field('Chức danh'), 'Senior Lecturer');
    await tester.enterText(field('Bộ môn'), 'Information Assurance');
    await tester.enterText(field('Chuyên môn (cách nhau bằng dấu phẩy)'), 'Cybersecurity, Cloud');
    await tester.enterText(field('Quota (số nhóm tối đa)'), '0');
    await tester.tap(find.text('Lưu'));
    await tester.pumpAndSettle();
    expect(find.text('Quota phải là số từ 1 trở lên'), findsOneWidget);

    await tester.enterText(field('Quota (số nhóm tối đa)'), '4');
    await tester.tap(find.text('Lưu'));
    await tester.pumpAndSettle();
    expect(fake.calls, ['create anhvq@fpt.edu.vn 4 Cybersecurity|Cloud']);
    expect(find.text('Đã thêm Dr. Vu Quoc Anh.'), findsOneWidget);
  });

  testWidgets('a rejected save shows why', (tester) async {
    final fake = await open(tester, FakeMentorAdmin([thanh]));
    fake.failWith = const AppFailure('Quota thấp hơn số nhóm đang hướng dẫn', 'Dr. Nguyen Thanh đang hướng dẫn 1 nhóm.');
    await tester.tap(find.text('Sửa'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Lưu'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Quota thấp hơn'), findsOneWidget);
  });

  testWidgets('archive asks first, then moves the lecturer to the archive', (tester) async {
    final fake = await open(tester, FakeMentorAdmin([thanh]));
    await tester.tap(find.widgetWithText(TextButton, 'Lưu trữ'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hủy'));
    await tester.pumpAndSettle();
    expect(fake.calls, isEmpty);

    await tester.tap(find.widgetWithText(TextButton, 'Lưu trữ'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Lưu trữ'));
    await tester.pumpAndSettle();
    expect(fake.calls, ['archive m_thanh true']);
    expect(find.textContaining('Không có giảng viên phù hợp'), findsOneWidget);

    await tester.tap(find.text('Đã lưu trữ'));
    await tester.pumpAndSettle();
    expect(find.text('Khôi phục'), findsOneWidget);
  });
}

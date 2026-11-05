import 'package:exematching/models/mentor.dart';
import 'package:exematching/models/student.dart';
import 'package:exematching/models/team.dart';
import 'package:exematching/models/view_state.dart';
import 'package:exematching/screens/mentor/mentor_detail_screen.dart';
import 'package:exematching/screens/mentor/mentor_list_screen.dart';
import 'package:exematching/services/local/local_database.dart';
import 'package:exematching/services/local/local_mentor_repository.dart';
import 'package:exematching/services/local/local_services.dart';
import 'package:exematching/services/local/local_team_repository.dart';
import 'package:exematching/services/services.dart';
import 'package:exematching/theme/app_theme.dart';
import 'package:exematching/viewmodels/mentor_detail_viewmodel.dart';
import 'package:exematching/viewmodels/mentor_list_viewmodel.dart';
import 'package:exematching/viewmodels/session_viewmodel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

const leader = Student(
  id: 's1',
  email: 'minh.le@fpt.edu.vn',
  fullName: 'Minh Le',
  studentCode: 'SE160234',
  major: 'SE',
  cohort: 'K16',
);
const member = Student(
  id: 's2',
  email: 'an.tran@fpt.edu.vn',
  fullName: 'An Tran',
  studentCode: 'SE161120',
  major: 'SE',
  cohort: 'K16',
);
const thanh = Mentor(
  id: 'm1',
  fullName: 'Dr. Nguyen Thanh',
  email: 'thanhnt@fpt.edu.vn',
  title: 'Head of AI Lab · Senior Lecturer',
  department: 'Software Engineering',
  expertise: ['AI/ML', 'Computer Vision'],
  bio: 'Specialises in edge AI and computer vision.',
  office: 'Room 304, Alpha Building, Hoa Lac Campus',
  maxQuota: 2,
);
const ha = Mentor(
  id: 'm2',
  fullName: 'MSc. Nguyen Thu Ha',
  email: 'hant@fpt.edu.vn',
  title: 'Lecturer · Mobile Development & HCI',
  department: 'Software Engineering',
  expertise: ['Mobile', 'Flutter'],
  bio: 'Mentors mobile product design.',
  maxQuota: 1,
  currentAssigned: 1,
  mentoredTeamNames: ['Campus Bite'],
);
const anh = Mentor(
  id: 'm3',
  fullName: 'Dr. Vu Quoc Anh',
  email: 'anhvq@fpt.edu.vn',
  title: 'Head of Security Lab',
  department: 'Information Assurance',
  expertise: ['Cybersecurity'],
  bio: 'Guides projects in cloud security.',
  maxQuota: 4,
);

TeamMember _member(Student s) => TeamMember.fromStudent(s, 'Developer');

/// Three members, Minh Le elected by a majority.
Team team({String id = 't1', String name = 'Team AI-04', String? mentorId}) => Team(
  id: id,
  code: 'AI-04',
  name: name,
  topic: 'Campus delivery drone',
  description: '',
  category: 'AI/ML',
  tags: const [],
  members: [
    _member(leader),
    _member(member),
    const TeamMember(studentId: 's3', fullName: 'Hoang Tran', studentCode: 'SE170456', role: 'QA'),
  ],
  openRoles: const [],
  supervisor: mentorId == null ? 'Assigned by Academic Office' : 'Someone',
  leaderId: 's1',
  votes: const {'s1': 's1', 's2': 's1'},
  mentorId: mentorId,
);

void main() {
  late LocalDatabase db;
  late LocalMentorRepository repo;

  setUp(() {
    db = LocalDatabase(latency: Duration.zero, requireNetwork: false);
    db.mentors.addAll({'m1': thanh, 'm2': ha, 'm3': anh});
    db.teams['t1'] = team();
    repo = LocalMentorRepository(db);
  });

  Future<void> send({String mentorId = 'm1', Student sender = leader, String teamId = 't1'}) =>
      repo.requestMentor(teamId: teamId, mentorId: mentorId, sender: sender, message: 'Please supervise us');

  Matcher failsWith(String code) => throwsA(isA<AppFailure>().having((f) => f.code, 'code', code));

  group('Mentor', () {
    test('initials skip the academic title', () {
      expect(thanh.initials, 'NT');
      expect(anh.initials, 'VA');
    });

    test('quota', () {
      expect(thanh.remainingSlots, 2);
      expect(ha.isAvailable, isFalse);
      expect(ha.remainingSlots, 0);
    });

    test('fromJson uses the id it is given', () {
      final m = Mentor.fromJson({'id': 'x', 'fullName': 'Dr. A B', 'maxQuota': 3, 'currentAssigned': 1});
      expect(m.id, 'x');
      expect(m.remainingSlots, 2);
    });
  });

  group('search', () {
    test('matches name, skill and availability', () async {
      expect(await repo.searchMentors(), hasLength(3));
      expect((await repo.searchMentors(query: 'vision')).single.id, 'm1');
      expect((await repo.searchMentors(expertise: 'Mobile')).single.id, 'm2');
      expect((await repo.searchMentors(availableOnly: true)).map((m) => m.id), ['m1', 'm3']);
    });
  });

  group('sending a request', () {
    test('the leader can ask a lecturer', () async {
      await send();
      final r = (await repo.requestOfTeam('t1'))!;
      expect(r.mentorName, 'Dr. Nguyen Thanh');
      expect(r.senderName, 'Minh Le');
      expect(r.isPending, isTrue);
    });

    test('a member who is not the leader cannot', () {
      expect(send(sender: member), failsWith('not-leader'));
    });

    test('a team without an elected leader cannot', () {
      db.teams['t1'] = team().copyWith(votes: const {'s1': 's1'});
      expect(send(), failsWith('not-leader'));
    });

    test('a full lecturer cannot be asked', () {
      expect(send(mentorId: 'm2'), failsWith('quota-full'));
    });

    test('a second lecturer cannot be asked while one is pending', () async {
      await send();
      expect(send(mentorId: 'm3'), failsWith('request-pending'));
    });

    test('withdrawing frees the team to ask someone else', () async {
      await send();
      await repo.withdrawRequest('t1');
      await send(mentorId: 'm3');
      expect((await repo.requestOfTeam('t1'))!.mentorId, 'm3');
    });

    test('a team with a mentor cannot ask again', () async {
      await send();
      await repo.respond(request: (await repo.requestOfTeam('t1'))!, accept: true);
      expect(send(mentorId: 'm3'), failsWith('has-mentor'));
    });
  });

  group('answering a request', () {
    test('accepting assigns the mentor and takes a quota slot', () async {
      await send();
      await repo.respond(request: (await repo.requestOfTeam('t1'))!, accept: true);

      final t = db.teams['t1']!;
      expect(t.mentorId, 'm1');
      expect(t.supervisor, 'Dr. Nguyen Thanh');
      expect(db.mentors['m1']!.currentAssigned, 1);
      expect(db.mentors['m1']!.mentoredTeamNames, ['Team AI-04']);
      expect((await repo.requestOfTeam('t1'))!.status, MentorRequestStatus.approved);
      expect((await repo.teamsOfMentor('m1')).single.id, 't1');
    });

    test('declining keeps the reason and lets the team ask again', () async {
      await send();
      await repo.respond(request: (await repo.requestOfTeam('t1'))!, accept: false, reason: 'Out of scope');

      final r = (await repo.requestOfTeam('t1'))!;
      expect(r.isRejected, isTrue);
      expect(r.decisionReason, 'Out of scope');
      expect(db.teams['t1']!.hasMentor, isFalse);
      expect(db.mentors['m1']!.currentAssigned, 0);

      await send(mentorId: 'm3');
      expect((await repo.requestOfTeam('t1'))!.isPending, isTrue);
    });

    test('a lecturer who filled up meanwhile cannot accept', () async {
      await send();
      final r = (await repo.requestOfTeam('t1'))!;
      db.mentors['m1'] = Mentor.fromJson({'id': 'm1', 'maxQuota': 1, 'currentAssigned': 1});
      expect(repo.respond(request: r, accept: true), failsWith('quota-full'));
    });

    test('a withdrawn or already answered request cannot be accepted', () async {
      await send();
      final r = (await repo.requestOfTeam('t1'))!;
      await repo.respond(request: r, accept: false);
      expect(repo.respond(request: r, accept: true), failsWith('request-closed'));
      await repo.withdrawRequest('t1');
      expect(repo.respond(request: r, accept: true), failsWith('request-closed'));
    });

    test('requests reach only the lecturer they were sent to', () async {
      await send();
      expect(await repo.watchRequestsForMentor('m1').first, hasLength(1));
      expect(await repo.watchRequestsForMentor('m3').first, isEmpty);
    });
  });

  group('what the profile offers', () {
    Future<MentorDetailViewModel> open(String mentorId, Student me) async {
      final vm = MentorDetailViewModel(
        mentorId,
        me,
        repo,
        LocalTeamRepository(db),
        DebugAnalyticsService(),
        DebugCrashReporter(),
      );
      await vm.load();
      return vm;
    }

    const outsider = Student(
      id: 's9',
      email: 'x@fpt.edu.vn',
      fullName: 'X Y',
      studentCode: 'SE1',
      major: '',
      cohort: '',
    );

    test('each situation maps to one action', () async {
      expect((await open('m1', outsider)).actionFor(thanh), MentorAction.noTeam);
      expect((await open('m1', member)).actionFor(thanh), MentorAction.notLeader);
      expect((await open('m1', leader)).actionFor(thanh), MentorAction.canRequest);
      expect((await open('m2', leader)).actionFor(ha), MentorAction.quotaFull);

      await send();
      expect((await open('m1', leader)).actionFor(thanh), MentorAction.pendingHere);
      expect((await open('m3', leader)).actionFor(anh), MentorAction.pendingElsewhere);

      await repo.respond(request: (await repo.requestOfTeam('t1'))!, accept: true);
      expect((await open('m1', leader)).actionFor(thanh), MentorAction.assigned);
      expect((await open('m3', leader)).actionFor(anh), MentorAction.otherMentor);
    });
  });

  group('screens fit a phone', () {
    Widget app<T extends ChangeNotifier>(Widget child, T vm, {required Student me}) => MultiProvider(
      providers: [
        ChangeNotifierProvider<SessionViewModel>(
          create: (_) => SessionViewModel(_FakeAuth(me), DebugAnalyticsService(), DebugCrashReporter()),
        ),
        ChangeNotifierProvider.value(value: vm),
      ],
      child: MaterialApp(theme: buildAppTheme(), home: child),
    );

    Future<void> pump(WidgetTester tester, Widget widget) async {
      tester.view.physicalSize = const Size(360, 740);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(widget);
      await tester.pumpAndSettle();
    }

    testWidgets('directory', (tester) async {
      final vm = MentorListViewModel(repo, DebugAnalyticsService(), DebugCrashReporter());
      await tester.runAsync(vm.load);
      await pump(tester, app(const MentorListScreen(), vm, me: leader));
      expect(find.text('Dr. Nguyen Thanh'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('profile, leader can request', (tester) async {
      final vm = MentorDetailViewModel(
        'm1',
        leader,
        repo,
        LocalTeamRepository(db),
        DebugAnalyticsService(),
        DebugCrashReporter(),
      );
      await tester.runAsync(vm.load);
      await pump(tester, app(const MentorDetailScreen(), vm, me: leader));
      await tester.scrollUntilVisible(find.text('Request as Mentor'), 200);
      expect(find.text('Request as Mentor'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}

class _FakeAuth implements AuthService {
  _FakeAuth(this.me);
  final Student me;

  @override
  Stream<Student?> authStateChanges() => Stream.value(me);
  @override
  Student? get currentStudent => me;
  @override
  Future<Student> signInWithGoogle() async => me;
  @override
  Future<void> signOut() async {}
}

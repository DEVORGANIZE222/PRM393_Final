import 'dart:async';

import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:web_admin/screens/mentor_requests_screen.dart';
import 'package:web_admin/viewmodels/mentor_requests_viewmodel.dart';

const mentor = Mentor(
  id: 'm1',
  fullName: 'Dr. Nguyen Thanh',
  email: 'thanhnt@fpt.edu.vn',
  title: 'Head of AI Lab',
  department: 'Software Engineering',
  expertise: ['AI/ML'],
  bio: '',
  maxQuota: 2,
);

MentorRequest pending() => MentorRequest(
  teamId: 't1',
  teamName: 'Team AI-04',
  mentorId: 'm1',
  mentorName: 'Dr. Nguyen Thanh',
  senderId: 's1',
  senderName: 'Minh Le',
  message: 'Please supervise us',
  createdAt: DateTime(2026, 11, 5),
);

/// Answers like Firestore does: the request stream re-emits after a write.
class FakeMentors implements MentorRepository {
  FakeMentors(this.requests);

  List<MentorRequest> requests;
  final _changes = StreamController<List<MentorRequest>>.broadcast();
  bool? accepted;
  String? reason;
  AppFailure? failure;

  @override
  Future<Mentor> getMentor(String mentorId) async => mentor;
  @override
  Future<List<Team>> teamsOfMentor(String mentorId) async => const [];
  @override
  Stream<List<MentorRequest>> watchRequestsForMentor(String mentorId) async* {
    yield requests;
    yield* _changes.stream;
  }

  @override
  Future<void> respond({required MentorRequest request, required bool accept, String? reason}) async {
    if (failure != null) throw failure!;
    accepted = accept;
    this.reason = reason;
    requests = [request.decided(accept: accept, reason: reason)];
    _changes.add(requests);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

void main() {
  Future<MentorRequestsViewModel> open(WidgetTester tester, FakeMentors repo, {String? mentorId = 'm1'}) async {
    tester.view.physicalSize = const Size(1100, 760);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final vm = MentorRequestsViewModel(repo, () async => mentorId);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: Scaffold(
          body: ChangeNotifierProvider.value(value: vm, child: const MentorRequestsView()),
        ),
      ),
    );
    await tester.runAsync(vm.load);
    await tester.pumpAndSettle();
    return vm;
  }

  testWidgets('shows a pending request, the quota and no overflow', (tester) async {
    await open(tester, FakeMentors([pending()]));
    expect(find.text('Team AI-04'), findsOneWidget);
    expect(find.text('Accept'), findsOneWidget);
    expect(find.text('1 waiting for your answer'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('empty queue', (tester) async {
    await open(tester, FakeMentors([]));
    expect(find.text('No requests yet'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('staff without a mentor profile', (tester) async {
    await open(tester, FakeMentors([]), mentorId: null);
    expect(find.text('No mentor profile on this account'), findsOneWidget);
  });

  testWidgets('accepting asks first, then writes', (tester) async {
    final repo = FakeMentors([pending()]);
    await open(tester, repo);
    await tester.tap(find.text('Accept'));
    await tester.pumpAndSettle();
    expect(repo.accepted, isNull);
    await tester.tap(find.text('Accept').last);
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
    await tester.pumpAndSettle();
    expect(repo.accepted, isTrue);
    expect(find.text('Approved'), findsOneWidget);
  });

  testWidgets('declining needs a reason', (tester) async {
    final repo = FakeMentors([pending()]);
    await open(tester, repo);
    await tester.tap(find.text('Decline'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Decline').last);
    await tester.pumpAndSettle();
    expect(repo.accepted, isNull, reason: 'no reason yet, the button is disabled');

    await tester.enterText(find.byType(TextField), 'Out of scope');
    await tester.pump();
    await tester.tap(find.text('Decline').last);
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
    await tester.pumpAndSettle();
    expect(repo.accepted, isFalse);
    expect(repo.reason, 'Out of scope');
    expect(find.text('Reason: Out of scope'), findsOneWidget);
  });

  testWidgets('a failed answer is shown to the lecturer', (tester) async {
    final repo = FakeMentors([pending()])..failure = MentorRules.requestClosed;
    await open(tester, repo);
    await tester.tap(find.text('Accept'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Accept').last);
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
    await tester.pumpAndSettle();
    expect(find.textContaining('no longer open'), findsOneWidget);
  });
}

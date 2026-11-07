/**
 * Security Rules Unit Tests (PRM393 Final - Appendix B)
 * Run against the Firebase Emulator Suite:
 * firebase emulators:exec --only firestore "npm test"
 */

const { assertFails, assertSucceeds, initializeTestEnvironment } = require('@firebase/rules-unit-testing');
const fs = require('fs');

let testEnv;

beforeAll(async () => {
  testEnv = await initializeTestEnvironment({
    projectId: 'prm393-final-exematching',
    firestore: {
      rules: fs.readFileSync('firebase/firestore.rules', 'utf8'),
      host: '127.0.0.1',
      port: 8080,
    },
  });
});

afterAll(async () => {
  await testEnv.cleanup();
});

beforeEach(async () => {
  await testEnv.clearFirestore();
});

describe('PRM393 Final Security Rules (Appendix B)', () => {
  test('R-01: team submission - leader cannot self-approve', async () => {
    const userDb = testEnv.authenticatedContext('student_01', { email: 'student@fpt.edu.vn' }).firestore();
    const docRef = userDb.collection('teamSubmissions').doc('team_01');
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await context.firestore().collection('allowedEmails').doc('student@fpt.edu.vn').set({ enabled: true });
      await context.firestore().collection('teams').doc('team_01').set({ locked: true, leaderId: 'student_01' });
    });
    
    // User tries to approve themselves directly
    await assertFails(docRef.set({
      teamId: 'team_01',
      leaderId: 'student_01',
      teamName: 'Team 01',
      lockCode: 'CM-01',
      memberSnapshot: [],
      status: 'approved',
      reason: '',
      submittedAt: new Date(),
    }));
  });

  test('R-02: admin updates pending team submission -> approved', async () => {
    // Setup pending doc as admin
    await testEnv.withSecurityRulesDisabled(async (adminContext) => {
      await adminContext.firestore().collection('users').doc('admin_01').set({ role: 'admin' });
      await adminContext.firestore().collection('teamSubmissions').doc('team_02').set({
        teamId: 'team_02',
        leaderId: 'student_02',
        teamName: 'Team 02',
        lockCode: 'CM-02',
        memberSnapshot: [],
        status: 'pending',
        reason: '',
      });
    });

    const adminDb = testEnv.authenticatedContext('admin_01', { email: 'admin@fpt.edu.vn' }).firestore();
    const docRef = adminDb.collection('teamSubmissions').doc('team_02');

    // Staff approves the pending submission
    await assertSucceeds(docRef.update({
      status: 'approved',
      reviewedBy: 'admin_01',
      reviewedAt: new Date(),
    }));
  });

  test('R-03: users - user update own role is DENIED', async () => {
    // Setup user
    await testEnv.withSecurityRulesDisabled(async (adminContext) => {
      await adminContext.firestore().collection('users').doc('student_03').set({
        email: 'student3@fpt.edu.vn',
        displayName: 'Student Three',
        role: 'user',
      });
    });

    const userDb = testEnv.authenticatedContext('student_03', { email: 'student3@fpt.edu.vn' }).firestore();
    const docRef = userDb.collection('users').doc('student_03');

    // User attempts privilege escalation
    await assertFails(docRef.update({
      role: 'admin',
    }));
  });

  describe('mentor selection', () => {
    const team = (extra = {}) => ({
      name: 'Team AI-04', supervisor: 'Assigned by Academic Office', leaderId: 'leader_01',
      members: [], memberIds: ['leader_01', 'member_01'], votes: {}, locked: false, invitesSent: 0, ...extra,
    });
    const request = (extra = {}) => ({
      teamId: 't1', teamName: 'Team AI-04', mentorId: 'm1', mentorName: 'Dr. A', senderId: 'leader_01',
      senderName: 'Leader', message: 'Please', status: 'pending', ...extra,
    });
    const mentor = (extra = {}) => ({
      fullName: 'Dr. A', email: 'a@fpt.edu.vn', maxQuota: 1, currentAssigned: 0, mentoredTeamNames: [],
      status: 'active', ...extra,
    });
    const student = (uid, email) => testEnv.authenticatedContext(uid, { email }).firestore();
    const lecturer = () => testEnv.authenticatedContext('lect_m1', { email: 'a@fpt.edu.vn' }).firestore();
    const otherLecturer = () => testEnv.authenticatedContext('lect_m2', { email: 'b@fpt.edu.vn' }).firestore();
    const admin = () => testEnv.authenticatedContext('admin_01', { email: 'admin@fpt.edu.vn' }).firestore();
    const leader = () => student('leader_01', 'leader@fpt.edu.vn');
    const member = () => student('member_01', 'member@fpt.edu.vn');

    const seed = (extra) => testEnv.withSecurityRulesDisabled(async (ctx) => {
      const db = ctx.firestore();
      await db.doc('allowedEmails/leader@fpt.edu.vn').set({ enabled: true });
      await db.doc('allowedEmails/member@fpt.edu.vn').set({ enabled: true });
      await db.doc('allowedEmails/a@fpt.edu.vn').set({ enabled: true, mentorId: 'm1' });
      await db.doc('allowedEmails/b@fpt.edu.vn').set({ enabled: true, mentorId: 'm2' });
      await db.doc('users/admin_01').set({ role: 'admin' });
      await db.doc('mentors/m1').set(mentor({ fullName: 'Dr. A' }));
      await db.doc('mentors/m2').set(mentor({ fullName: 'Dr. B', currentAssigned: 1, mentoredTeamNames: ['X'] }));
      await db.doc('teams/t1').set(team());
      if (extra) await extra(db);
    });
    const pending = (db) => db.doc('mentor_requests/t1').set(request());

    const accept = (db, { mentorId = 'm1', name = 'Dr. A', assigned = 1 } = {}) => {
      const batch = db.batch();
      batch.update(db.doc('mentor_requests/t1'), { status: 'approved' });
      batch.update(db.doc('teams/t1'), { mentorId, supervisor: name });
      batch.update(db.doc(`mentors/${mentorId}`), { currentAssigned: assigned, mentoredTeamNames: ['Team AI-04'] });
      batch.set(db.doc('students/leader_01/notifications/n1'), { teamId: 't1', title: 'Accepted', read: false });
      return batch.commit();
    };

    test('R-04: mentors - student reads the directory', async () => {
      await seed();
      await assertSucceeds(member().doc('mentors/m1').get());
    });

    test('R-05: mentors - student cannot change a quota', async () => {
      await seed();
      await assertFails(leader().doc('mentors/m1').update({ currentAssigned: 0, maxQuota: 99 }));
    });

    test('R-06: mentor_requests - leader creates a pending request', async () => {
      await seed();
      await assertSucceeds(leader().doc('mentor_requests/t1').set(request()));
    });

    test('R-07: mentor_requests - a member who is not the leader is denied', async () => {
      await seed();
      await assertFails(member().doc('mentor_requests/t1').set(request({ senderId: 'member_01' })));
    });

    test('R-08: mentor_requests - leader cannot create an approved request', async () => {
      await seed();
      await assertFails(leader().doc('mentor_requests/t1').set(request({ status: 'approved' })));
    });

    test('R-09: mentor_requests - a team with a mentor cannot ask again', async () => {
      await seed((db) => db.doc('teams/t1').update({ mentorId: 'm2' }));
      await assertFails(leader().doc('mentor_requests/t1').set(request()));
    });

    test('R-10: mentor_requests - a second request cannot replace a pending one', async () => {
      await seed(pending);
      await assertFails(leader().doc('mentor_requests/t1').set(request({ mentorId: 'm2' })));
    });

    test('R-11: mentor_requests - leader asks again after a refusal', async () => {
      await seed((db) => db.doc('mentor_requests/t1').set(request({ status: 'rejected' })));
      await assertSucceeds(leader().doc('mentor_requests/t1').set(request({ mentorId: 'm2', mentorName: 'Dr. B' })));
    });

    test('R-12: mentor_requests - leader withdraws a pending request', async () => {
      await seed(pending);
      await assertSucceeds(leader().doc('mentor_requests/t1').delete());
    });

    test('R-13: mentor_requests - a member cannot withdraw it', async () => {
      await seed(pending);
      await assertFails(member().doc('mentor_requests/t1').delete());
    });

    test('R-14: mentor_requests - the asked lecturer declines with a reason', async () => {
      await seed(pending);
      await assertSucceeds(lecturer().doc('mentor_requests/t1').update({ status: 'rejected', decisionReason: 'Full' }));
    });

    test('R-15: mentor_requests - another lecturer cannot answer', async () => {
      await seed(pending);
      await assertFails(otherLecturer().doc('mentor_requests/t1').update({ status: 'rejected' }));
    });

    test('R-16: mentor_requests - a student cannot approve their own request', async () => {
      await seed(pending);
      await assertFails(leader().doc('mentor_requests/t1').update({ status: 'approved' }));
    });

    test('R-17: accept - request, team and quota change in one write', async () => {
      await seed(pending);
      await assertSucceeds(accept(lecturer()));
    });

    test('R-18: accept - a locked team can still get its mentor', async () => {
      await seed(async (db) => {
        await pending(db);
        await db.doc('teams/t1').update({ locked: true });
      });
      await assertSucceeds(accept(lecturer()));
    });

    test('R-19: accept - a lecturer cannot go over quota', async () => {
      await seed((db) => db.doc('mentor_requests/t1').set(request({ mentorId: 'm2', mentorName: 'Dr. B' })));
      await assertFails(accept(otherLecturer(), { mentorId: 'm2', name: 'Dr. B', assigned: 2 }));
    });

    test('R-20: teams - a lecturer cannot claim a team without an approved request', async () => {
      await seed(pending);
      await assertFails(lecturer().doc('teams/t1').update({ mentorId: 'm1', supervisor: 'Dr. A' }));
    });

    test('R-21: teams - a leader cannot set the mentor directly', async () => {
      await seed();
      await assertFails(leader().doc('teams/t1').update({ mentorId: 'm1', supervisor: 'Dr. A' }));
    });

    test('R-22: mentors - admin creates a lecturer', async () => {
      await seed();
      await assertSucceeds(admin().doc('mentors/m9').set(mentor({ fullName: 'Dr. C' })));
    });

    test('R-23: mentors - a student cannot create a lecturer', async () => {
      await seed();
      await assertFails(leader().doc('mentors/m9').set(mentor()));
    });

    test('R-24: mentors - admin edits the profile and archives', async () => {
      await seed();
      await assertSucceeds(admin().doc('mentors/m1').update({ title: 'Lecturer', maxQuota: 3, status: 'archived' }));
    });

    test('R-25: mentors - admin cannot fake a team count', async () => {
      await seed();
      await assertFails(admin().doc('mentors/m1').update({ currentAssigned: 1 }));
    });

    test('R-26: mentors - admin cannot set a quota below the teams supervised', async () => {
      await seed((db) => db.doc('mentors/m1').update({ maxQuota: 3, currentAssigned: 2 }));
      await assertFails(admin().doc('mentors/m1').update({ maxQuota: 1 }));
    });

    test('R-27: mentors - nobody deletes a lecturer', async () => {
      await seed();
      await assertFails(admin().doc('mentors/m1').delete());
    });

    test('R-28: mentor_requests - an archived lecturer cannot be asked', async () => {
      await seed((db) => db.doc('mentors/m1').update({ status: 'archived' }));
      await assertFails(leader().doc('mentor_requests/t1').set(request()));
    });

    test('R-29: allowedEmails - a student cannot link themselves to a lecturer', async () => {
      await seed();
      await assertFails(leader().doc('allowedEmails/leader@fpt.edu.vn').update({ mentorId: 'm1' }));
    });

    test('R-30: allowedEmails - admin links a lecturer account', async () => {
      await seed();
      await assertSucceeds(admin().doc('allowedEmails/c@fpt.edu.vn').set({ enabled: true, mentorId: 'm1' }));
    });

    test('R-31: notifications - a lecturer who answered reaches the leader', async () => {
      await seed(pending);
      await assertSucceeds(accept(lecturer()));
    });

    test('R-32: notifications - another lecturer cannot write to a student inbox', async () => {
      await seed(pending);
      await assertFails(otherLecturer().doc('students/leader_01/notifications/n2').set({ teamId: 't1', title: 'Spam' }));
    });

    test('R-33: mentor_requests - admin reads every request', async () => {
      await seed(pending);
      await assertSucceeds(admin().doc('mentor_requests/t1').get());
    });
  });
});

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
  test('R-01: registrations - user create with status=approved is DENIED', async () => {
    const userDb = testEnv.authenticatedContext('student_01', { email: 'student@fpt.edu.vn' }).firestore();
    const docRef = userDb.collection('registrations').doc('reg_01');
    
    // User tries to approve themselves directly
    await assertFails(docRef.set({
      eventId: 'ev_01',
      uid: 'student_01',
      status: 'approved',
      reason: 'Self approve',
      createdAt: new Date(),
    }));
  });

  test('R-02: registrations - staff update pending -> approved is ALLOWED', async () => {
    // Setup pending doc as admin
    await testEnv.withSecurityRulesDisabled(async (adminContext) => {
      await adminContext.firestore().collection('users').doc('staff_01').set({ role: 'staff' });
      await adminContext.firestore().collection('registrations').doc('reg_02').set({
        eventId: 'ev_01',
        uid: 'student_02',
        status: 'pending',
        reason: '',
      });
    });

    const staffDb = testEnv.authenticatedContext('staff_01', { email: 'staff@fpt.edu.vn' }).firestore();
    const docRef = staffDb.collection('registrations').doc('reg_02');

    // Staff approves the pending submission
    await assertSucceeds(docRef.update({
      status: 'approved',
      reason: 'Verified qualification',
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
    const student = (uid, email) => testEnv.authenticatedContext(uid, { email }).firestore();
    const lecturer = () => testEnv.authenticatedContext('staff_m1', { email: 'a@fpt.edu.vn' }).firestore();
    const otherLecturer = () => testEnv.authenticatedContext('staff_m2', { email: 'b@fpt.edu.vn' }).firestore();
    const leader = () => student('leader_01', 'leader@fpt.edu.vn');
    const member = () => student('member_01', 'member@fpt.edu.vn');

    const seed = (extra) => testEnv.withSecurityRulesDisabled(async (ctx) => {
      const db = ctx.firestore();
      await db.doc('allowedEmails/leader@fpt.edu.vn').set({ enabled: true });
      await db.doc('allowedEmails/member@fpt.edu.vn').set({ enabled: true });
      await db.doc('users/staff_m1').set({ role: 'staff', mentorId: 'm1' });
      await db.doc('users/staff_m2').set({ role: 'staff', mentorId: 'm2' });
      await db.doc('mentors/m1').set({ fullName: 'Dr. A', maxQuota: 1, currentAssigned: 0, mentoredTeamNames: [] });
      await db.doc('mentors/m2').set({ fullName: 'Dr. B', maxQuota: 1, currentAssigned: 1, mentoredTeamNames: ['X'] });
      await db.doc('teams/t1').set(team());
      if (extra) await extra(db);
    });
    const pending = (db) => db.doc('mentor_requests/t1').set(request());

    const accept = (db, { mentorId = 'm1', name = 'Dr. A', assigned = 1 } = {}) => {
      const batch = db.batch();
      batch.update(db.doc('mentor_requests/t1'), { status: 'approved' });
      batch.update(db.doc('teams/t1'), { mentorId, supervisor: name });
      batch.update(db.doc(`mentors/${mentorId}`), { currentAssigned: assigned, mentoredTeamNames: ['Team AI-04'] });
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

    test('R-22: users - nobody links themselves to a lecturer on sign-up', async () => {
      await seed();
      await assertFails(student('new_01', 'new@fpt.edu.vn').doc('users/new_01').set({ role: 'user', mentorId: 'm1' }));
    });
  });
});

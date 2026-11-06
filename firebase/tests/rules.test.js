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
});


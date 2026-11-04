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
});


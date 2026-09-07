import admin from 'firebase-admin';

import { env } from '../config/env';

let firebaseApp: admin.app.App | undefined;

export function getFirebaseApp() {
  if (firebaseApp) return firebaseApp;

  if (env.FIREBASE_PROJECT_ID && env.FIREBASE_PRIVATE_KEY && env.FIREBASE_CLIENT_EMAIL) {
    firebaseApp = admin.initializeApp({
      credential: admin.credential.cert({
        projectId: env.FIREBASE_PROJECT_ID,
        clientEmail: env.FIREBASE_CLIENT_EMAIL,
        // Replace escaped newline characters from .env string
        privateKey: env.FIREBASE_PRIVATE_KEY.replace(/\\n/g, '\n'),
      }),
    });
    // eslint-disable-next-line no-console
    console.log('📦 Firebase Admin initialized successfully.');
  } else {
    // eslint-disable-next-line no-console
    console.warn('⚠️ Firebase Admin credentials missing. Push notifications will be disabled.');
  }

  return firebaseApp;
}

// Export messaging directly for convenience
export function getFirebaseMessaging() {
  const app = getFirebaseApp();
  if (!app) return null;
  return admin.messaging(app);
}

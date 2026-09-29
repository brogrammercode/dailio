import { createApp } from './app';

// Vercel imports this module as a request handler. Keep local listeners and
// long-lived maintenance timers in server.ts only.
const app = createApp();

export { app };
export default app;

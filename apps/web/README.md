# Dailio Web

React + TypeScript + Tailwind member web client for QR-first attendance and subscription flows.

## Development

From the repository root:

```bash
pnpm install
pnpm --filter web dev
```

Copy `.env.example` to `.env` and set:

- `VITE_API_BASE_URL` to the API `/api/v1` origin;
- `VITE_GOOGLE_CLIENT_ID` to the browser OAuth client ID.

The API must allow the web origin in `CORS_ORIGIN` and must set `WEB_APP_BASE_URL` to the deployed web origin so newly generated QR codes open in the browser.

## Verification

```bash
pnpm --filter web type-check
pnpm --filter web lint
pnpm --filter web test
pnpm --filter web build
```

For local verification, camera and geolocation are allowed on `localhost`. Production attendance evidence requires HTTPS. QR attendance is server-confirmed and never works offline.

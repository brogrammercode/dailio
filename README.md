# Dailio

A multi-tenant gym management platform for owners, admins/staff, and members.

## Stack

| Layer | Technology |
|---|---|
| Mobile | Flutter (Bloc, go_router, Material 3) |
| API | Express.js + TypeScript |
| Database | PostgreSQL (Prisma ORM) |
| Queue / Jobs | BullMQ + Redis |
| Media Storage | S3-compatible (MinIO locally) |
| Push | Firebase Cloud Messaging |

## Quick Start

### Prerequisites
- Node.js ≥ 20
- pnpm ≥ 9 (`npm i -g pnpm`)
- Flutter SDK ≥ 3.32
- Docker + Docker Compose

### 1. Clone and install

```bash
git clone <repo-url>
pnpm install
```

### 2. Configure environment

```bash
cp .env.example .env
# Fill in .env values
```

### 3. Start infrastructure

```bash
docker compose up -d postgres redis minio
```

### 4. Run database migrations

```bash
pnpm db:migrate
```

For an existing database created before Prisma migration tracking was introduced, do not mark these migrations as applied before creating their tables. Execute the additive migration SQL files first, then record them with `prisma migrate resolve --applied <migration_name>`. The exact procedure is tracked in `FEE_SUBSCRIPTION_FLOW_REPORT.md`; never use `db:reset` against shared or production data.

### 5. Seed demo data

```bash
pnpm db:seed
```

### 6. Start API

```bash
pnpm dev
```

API runs at http://localhost:3000  
Swagger docs at http://localhost:3000/api/docs

### 7. Start Flutter app

```bash
cd apps/mobile
flutter run
```

### 8. Shorebird releases and patches

The Flutter app is initialized as `Dailio` for Shorebird code-push releases.
On a new development machine, sign in from `apps/mobile` and verify the setup:

```bash
shorebird login
shorebird doctor
```

The committed `apps/mobile/shorebird.yaml` identifies the Dailio Shorebird app.
Create a store release
with `shorebird release --platforms android` or `shorebird release --platforms ios`.
Dart-only fixes can be delivered with
`shorebird patch --platforms android --release-version <version>` or the
equivalent iOS command. Native changes require a new store release.

The manual GitHub Actions workflow is documented in
[`apps/mobile/SHOREBIRD.md`](apps/mobile/SHOREBIRD.md). It requires the
repository secret `SHOREBIRD_TOKEN` and production signing configuration.

## Project Structure

```
gym/
  apps/
    api/          # Express + TypeScript API
    mobile/       # Flutter mobile app
  .github/
    workflows/    # GitHub Actions CI
  docker-compose.yml
  CONTEXT.md      # Product and engineering spec (authoritative)
  AGENTS.md       # Agent working rules
```

## Documentation

- [Product & Engineering Context](./CONTEXT.md) — authoritative spec
- [API Docs](http://localhost:3000/api/docs) — Swagger UI (when running)
- [Shorebird setup](./apps/mobile/SHOREBIRD.md) — release and patch workflow

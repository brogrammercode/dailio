# Gym Management Platform

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

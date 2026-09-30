CREATE TABLE IF NOT EXISTS "holidays" (
  "id" TEXT NOT NULL,
  "organization_id" TEXT NOT NULL,
  "branch_id" TEXT,
  "name" TEXT NOT NULL,
  "date" TIMESTAMP(3) NOT NULL,
  "is_recurring" BOOLEAN NOT NULL DEFAULT false,
  "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updated_at" TIMESTAMP(3) NOT NULL,
  CONSTRAINT "holidays_pkey" PRIMARY KEY ("id")
);

ALTER TABLE "holidays"
  ADD COLUMN IF NOT EXISTS "end_date" TIMESTAMP(3),
  ADD COLUMN IF NOT EXISTS "idempotency_key" TEXT;

ALTER TABLE "announcements" ADD COLUMN IF NOT EXISTS "automation_key" TEXT;
CREATE UNIQUE INDEX IF NOT EXISTS "announcements_automation_key_key"
  ON "announcements"("automation_key");

CREATE UNIQUE INDEX "holidays_idempotency_key_key" ON "holidays"("idempotency_key");

CREATE TABLE "attendance_streaks" (
  "id" TEXT NOT NULL,
  "organization_id" TEXT NOT NULL,
  "branch_id" TEXT NOT NULL,
  "member_id" TEXT NOT NULL,
  "current_streak" INTEGER NOT NULL DEFAULT 0,
  "best_streak" INTEGER NOT NULL DEFAULT 0,
  "last_attendance_date" DATE,
  "calculated_for_date" DATE NOT NULL,
  "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updated_at" TIMESTAMP(3) NOT NULL,

  CONSTRAINT "attendance_streaks_pkey" PRIMARY KEY ("id")
);

CREATE UNIQUE INDEX "attendance_streaks_organization_id_branch_id_member_id_key"
  ON "attendance_streaks"("organization_id", "branch_id", "member_id");
CREATE INDEX "attendance_streaks_organization_id_branch_id_current_streak_idx"
  ON "attendance_streaks"("organization_id", "branch_id", "current_streak");

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'holidays_organization_id_fkey') THEN
    ALTER TABLE "holidays" ADD CONSTRAINT "holidays_organization_id_fkey"
      FOREIGN KEY ("organization_id") REFERENCES "organizations"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'holidays_branch_id_fkey') THEN
    ALTER TABLE "holidays" ADD CONSTRAINT "holidays_branch_id_fkey"
      FOREIGN KEY ("branch_id") REFERENCES "branches"("id") ON DELETE SET NULL ON UPDATE CASCADE;
  END IF;
END $$;

ALTER TABLE "attendance_streaks"
  ADD CONSTRAINT "attendance_streaks_organization_id_fkey"
  FOREIGN KEY ("organization_id") REFERENCES "organizations"("id") ON DELETE RESTRICT ON UPDATE CASCADE,
  ADD CONSTRAINT "attendance_streaks_branch_id_fkey"
  FOREIGN KEY ("branch_id") REFERENCES "branches"("id") ON DELETE RESTRICT ON UPDATE CASCADE,
  ADD CONSTRAINT "attendance_streaks_member_id_fkey"
  FOREIGN KEY ("member_id") REFERENCES "members"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

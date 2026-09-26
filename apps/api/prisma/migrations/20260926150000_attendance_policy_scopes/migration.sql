-- Additive attendance policy scoping and permanent gate attendance source.
ALTER TYPE "AttendanceSessionSource" ADD VALUE IF NOT EXISTS 'QR_GATE';

ALTER TABLE "attendance_policies"
  ADD COLUMN "member_id" TEXT;

ALTER TABLE "attendance_sessions"
  ADD COLUMN "policy_snapshot" JSONB,
  ADD COLUMN "branch_timezone" TEXT,
  ADD COLUMN "clock_out_source" TEXT;

ALTER TABLE "attendance_policies"
  ADD CONSTRAINT "attendance_policies_scope_check"
  CHECK (NOT ("role_id" IS NOT NULL AND "member_id" IS NOT NULL));

ALTER TABLE "attendance_policies"
  ADD CONSTRAINT "attendance_policies_member_id_fkey"
  FOREIGN KEY ("member_id") REFERENCES "members"("id") ON DELETE SET NULL ON UPDATE CASCADE;

CREATE INDEX "attendance_policies_organization_id_branch_id_role_id_idx"
  ON "attendance_policies"("organization_id", "branch_id", "role_id");

CREATE INDEX "attendance_policies_organization_id_branch_id_member_id_idx"
  ON "attendance_policies"("organization_id", "branch_id", "member_id");

-- Existing rows remain branch defaults. Only one active scope is resolved by the
-- application using the latest effective version; historical versions remain immutable.

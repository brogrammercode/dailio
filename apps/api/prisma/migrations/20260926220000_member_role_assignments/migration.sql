-- Support deterministic multi-role assignments while retaining members.role_id
-- as the backwards-compatible primary role projection.
CREATE TABLE "member_role_assignments" (
  "id" TEXT NOT NULL,
  "organization_id" TEXT NOT NULL,
  "branch_id" TEXT NOT NULL,
  "member_id" TEXT NOT NULL,
  "role_id" TEXT NOT NULL,
  "priority" INTEGER NOT NULL DEFAULT 100,
  "effective_from" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "effective_to" TIMESTAMP(3),
  "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updated_at" TIMESTAMP(3) NOT NULL,
  CONSTRAINT "member_role_assignments_pkey" PRIMARY KEY ("id")
);

CREATE UNIQUE INDEX "member_role_assignments_member_id_role_id_effective_from_key"
  ON "member_role_assignments"("member_id", "role_id", "effective_from");
CREATE INDEX "member_role_assignments_org_branch_member_priority_idx"
  ON "member_role_assignments"("organization_id", "branch_id", "member_id", "priority");
CREATE INDEX "member_role_assignments_org_branch_role_idx"
  ON "member_role_assignments"("organization_id", "branch_id", "role_id");
CREATE UNIQUE INDEX "member_role_assignments_one_active_role_idx"
  ON "member_role_assignments"("member_id", "role_id")
  WHERE "effective_to" IS NULL;

INSERT INTO "member_role_assignments"
  ("id", "organization_id", "branch_id", "member_id", "role_id", "priority", "effective_from", "created_at", "updated_at")
SELECT
  'mra_' || "id",
  "organization_id",
  "branch_id",
  "id",
  "role_id",
  100,
  "created_at",
  "created_at",
  CURRENT_TIMESTAMP
FROM "members"
WHERE "role_id" IS NOT NULL;

ALTER TABLE "member_role_assignments"
  ADD CONSTRAINT "member_role_assignments_member_id_fkey"
  FOREIGN KEY ("member_id") REFERENCES "members"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "member_role_assignments"
  ADD CONSTRAINT "member_role_assignments_role_id_fkey"
  FOREIGN KEY ("role_id") REFERENCES "roles"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

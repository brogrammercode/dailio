-- Add an explicit branch-scoped reporting relationship. Existing members
-- remain top-level until an authorized manager assigns them.
ALTER TABLE "members"
  ADD COLUMN "manager_member_id" TEXT;

CREATE INDEX "members_organization_id_branch_id_manager_member_id_idx"
  ON "members"("organization_id", "branch_id", "manager_member_id");

ALTER TABLE "members"
  ADD CONSTRAINT "members_manager_member_id_fkey"
  FOREIGN KEY ("manager_member_id") REFERENCES "members"("id")
  ON DELETE SET NULL ON UPDATE CASCADE;

ALTER TABLE "members"
  ADD CONSTRAINT "members_manager_not_self_check"
  CHECK ("manager_member_id" IS NULL OR "manager_member_id" <> "id");

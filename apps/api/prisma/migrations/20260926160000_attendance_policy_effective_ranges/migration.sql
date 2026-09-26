-- Make policy version ranges explicit so only one version per scope can be active.
ALTER TABLE "attendance_policies"
  ADD COLUMN "effective_to" TIMESTAMP(3);

WITH ordered AS (
  SELECT
    "id",
    LEAD("effective_from") OVER (
      PARTITION BY "organization_id", "branch_id", "role_id", "member_id"
      ORDER BY "effective_from", "version", "id"
    ) AS "next_effective_from"
  FROM "attendance_policies"
)
UPDATE "attendance_policies" AS policy
SET "effective_to" = ordered."next_effective_from"
FROM ordered
WHERE policy."id" = ordered."id"
  AND ordered."next_effective_from" IS NOT NULL;

CREATE UNIQUE INDEX "attendance_policies_one_active_scope_idx"
  ON "attendance_policies"(
    "organization_id",
    "branch_id",
    COALESCE("role_id", ''),
    COALESCE("member_id", '')
  )
  WHERE "effective_to" IS NULL;

CREATE INDEX "attendance_policies_effective_range_idx"
  ON "attendance_policies"("organization_id", "branch_id", "effective_from", "effective_to");

-- The domain allows only one open session per member at a time. The service
-- also checks this inside a serializable transaction; this index is the final
-- database-level guard for concurrent requests.
CREATE UNIQUE INDEX "attendance_sessions_one_open_per_member_idx"
  ON "attendance_sessions"("member_id")
  WHERE "state" = 'OPEN';

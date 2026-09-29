-- A user may submit multiple join requests over time. Only one request may
-- be pending for a user and branch at a time; approved/rejected history must
-- remain append-only and must not block a later rejoin request.

DO $$
BEGIN
  IF EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'join_requests_user_id_branch_id_status_key'
  ) THEN
    ALTER TABLE "join_requests"
      DROP CONSTRAINT "join_requests_user_id_branch_id_status_key";
  END IF;
END $$;

DROP INDEX IF EXISTS "join_requests_user_id_branch_id_status_key";

CREATE UNIQUE INDEX IF NOT EXISTS "join_requests_one_pending_per_user_branch_idx"
  ON "join_requests"("user_id", "branch_id")
  WHERE "status" = 'PENDING';

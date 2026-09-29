-- A rejoin request may refer to a member that already has an older approved
-- request. Keep request history without making member_id one-to-one.

DROP INDEX IF EXISTS "join_requests_member_id_key";

CREATE INDEX IF NOT EXISTS "join_requests_member_id_idx"
  ON "join_requests"("member_id");

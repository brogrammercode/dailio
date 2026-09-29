-- Keep branch attendance period queries index-backed while preserving the
-- stable clock_in_at/id ordering used by cursor pagination.
CREATE INDEX "attendance_sessions_org_branch_clock_in_id_idx"
  ON "attendance_sessions"("organization_id", "branch_id", "clock_in_at", "id");

-- Preserve every attendance correction as an immutable before/after record.
ALTER TABLE "attendance_sessions"
  ADD COLUMN "correction_version" INTEGER NOT NULL DEFAULT 0;

CREATE TABLE "attendance_corrections" (
  "id" TEXT NOT NULL,
  "session_id" TEXT NOT NULL,
  "organization_id" TEXT NOT NULL,
  "branch_id" TEXT NOT NULL,
  "version" INTEGER NOT NULL,
  "actor_id" TEXT NOT NULL,
  "previous_clock_in_at" TIMESTAMP(3) NOT NULL,
  "previous_clock_out_at" TIMESTAMP(3),
  "previous_state" "AttendanceSessionState" NOT NULL,
  "previous_derived_status" "AttendanceDerivedStatus",
  "corrected_clock_in_at" TIMESTAMP(3) NOT NULL,
  "corrected_clock_out_at" TIMESTAMP(3),
  "corrected_state" "AttendanceSessionState" NOT NULL,
  "corrected_derived_status" "AttendanceDerivedStatus",
  "reason" TEXT NOT NULL,
  "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

  CONSTRAINT "attendance_corrections_pkey" PRIMARY KEY ("id")
);

CREATE UNIQUE INDEX "attendance_corrections_session_id_version_key"
  ON "attendance_corrections"("session_id", "version");

CREATE INDEX "attendance_corrections_organization_id_branch_id_idx"
  ON "attendance_corrections"("organization_id", "branch_id");

CREATE INDEX "attendance_corrections_session_id_created_at_idx"
  ON "attendance_corrections"("session_id", "created_at");

ALTER TABLE "attendance_corrections"
  ADD CONSTRAINT "attendance_corrections_session_id_fkey"
  FOREIGN KEY ("session_id") REFERENCES "attendance_sessions"("id")
  ON DELETE RESTRICT ON UPDATE CASCADE;

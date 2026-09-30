ALTER TABLE "attendance_policies"
  ADD COLUMN IF NOT EXISTS "qr_scan_on_clock_in" BOOLEAN NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS "qr_scan_on_clock_out" BOOLEAN NOT NULL DEFAULT false;

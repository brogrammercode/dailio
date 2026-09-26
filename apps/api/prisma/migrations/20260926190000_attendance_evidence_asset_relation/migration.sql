-- Keep private selfie metadata linked to its media asset for safe retention cleanup.
CREATE INDEX "attendance_evidence_asset_id_idx"
  ON "attendance_evidence"("asset_id");

ALTER TABLE "attendance_evidence"
  ADD CONSTRAINT "attendance_evidence_asset_id_fkey"
  FOREIGN KEY ("asset_id") REFERENCES "media_assets"("id")
  ON DELETE SET NULL ON UPDATE CASCADE;

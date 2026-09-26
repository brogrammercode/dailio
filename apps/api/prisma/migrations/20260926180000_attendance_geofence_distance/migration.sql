-- Store only the derived geofence distance; precise coordinates remain private.
ALTER TABLE "attendance_evidence"
  ADD COLUMN "geofence_distance_meters" DOUBLE PRECISION;

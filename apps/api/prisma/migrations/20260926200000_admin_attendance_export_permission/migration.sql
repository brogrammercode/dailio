-- Existing seeded admins should retain the same authorized attendance export
-- capability as newly created admin roles.
UPDATE "roles"
SET "permissions" = array_append("permissions", 'ATTENDANCE_EXPORT')
WHERE "system_key" = 'ADMIN'
  AND NOT ('ATTENDANCE_EXPORT' = ANY("permissions"));

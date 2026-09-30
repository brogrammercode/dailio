UPDATE "roles"
SET "permissions" = array_append("permissions", 'ATTENDANCE_VOID')
WHERE "system_key" IN ('OWNER', 'ADMIN')
  AND NOT ('ATTENDANCE_VOID' = ANY("permissions"));

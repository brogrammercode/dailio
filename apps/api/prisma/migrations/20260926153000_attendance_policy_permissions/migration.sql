-- Backfill attendance policy/evidence permissions for already-seeded system roles.
UPDATE "roles"
SET "permissions" = (
  SELECT ARRAY(
    SELECT DISTINCT permission
    FROM unnest(
      "permissions" || ARRAY[
        'ATTENDANCE_POLICY_READ',
        'ATTENDANCE_POLICY_MANAGE',
        'ATTENDANCE_POLICY_ASSIGN',
        'ATTENDANCE_EVIDENCE_READ_ALL'
      ]::text[]
    ) AS permission
  )
)
WHERE "system_key" IN ('OWNER', 'ADMIN');

UPDATE "roles"
SET "permissions" = (
  SELECT ARRAY(
    SELECT DISTINCT permission
    FROM unnest("permissions" || ARRAY['ATTENDANCE_EVIDENCE_READ_SELF']::text[]) AS permission
  )
)
WHERE "system_key" = 'MEMBER';

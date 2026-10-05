-- Meal entitlements are operational access rules. Backfill them into
-- subscriptions that can still be used without changing financial terms.
UPDATE "subscriptions" AS s
SET "plan_snapshot" = jsonb_set(
  CASE
    WHEN jsonb_typeof(s."plan_snapshot") = 'object' THEN s."plan_snapshot"
    ELSE '{}'::jsonb
  END,
  '{meal_entitlements}',
  COALESCE(
    (
      SELECT jsonb_agg(
        jsonb_build_object(
          'meal_slot_id', e."meal_slot_id",
          'max_servings_per_day', e."max_servings_per_day"
        )
        ORDER BY e."created_at"
      )
      FROM "plan_meal_entitlements" AS e
      WHERE e."organization_id" = s."organization_id"
        AND e."branch_id" = s."branch_id"
        AND e."plan_id" = s."plan_id"
        AND e."is_active" = true
    ),
    '[]'::jsonb
  ),
  true
)
WHERE s."status" IN ('DRAFT', 'UPCOMING', 'ACTIVE', 'PAUSED')
  AND EXISTS (
    SELECT 1
    FROM "plan_meal_entitlements" AS e
    WHERE e."organization_id" = s."organization_id"
      AND e."branch_id" = s."branch_id"
      AND e."plan_id" = s."plan_id"
  );

-- Holidays now support explicit non-contiguous dates and recurring weekdays.
-- The legacy date/end_date columns stay available for one compatibility window.
ALTER TABLE "holidays"
  ADD COLUMN IF NOT EXISTS "dates" JSONB NOT NULL DEFAULT '[]'::jsonb,
  ADD COLUMN IF NOT EXISTS "recurring_weekdays" JSONB NOT NULL DEFAULT '[]'::jsonb;

ALTER TABLE "holidays" ALTER COLUMN "date" DROP NOT NULL;

-- Preserve every existing date-range holiday as an explicit date list.
UPDATE "holidays" AS holiday
SET "dates" = dates.days
FROM (
  SELECT h.id,
         COALESCE(
           (
             SELECT jsonb_agg(to_char(day, 'YYYY-MM-DD') ORDER BY day)
             FROM generate_series(h.date::date, COALESCE(h.end_date, h.date)::date, interval '1 day') AS day
           ),
           '[]'::jsonb
         ) AS days
  FROM "holidays" AS h
) AS dates
WHERE holiday.id = dates.id
  AND holiday."dates" = '[]'::jsonb
  AND holiday.date IS NOT NULL;

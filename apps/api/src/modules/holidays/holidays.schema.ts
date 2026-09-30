import { z } from 'zod';

const localDate = z.string().regex(/^\d{4}-\d{2}-\d{2}$/, 'Use YYYY-MM-DD dates');
const weekdays = z
  .array(z.number().int().min(1).max(7))
  .max(7)
  .refine((values) => new Set(values).size === values.length, 'Weekdays must be unique');

const holidayFields = {
  name: z.string().trim().min(1).max(160),
  dates: z.array(localDate).max(366).optional(),
  recurring_weekdays: weekdays.optional(),
  // Kept for one release so older clients can still create/update a holiday.
  date: localDate.optional(),
  end_date: localDate.nullable().optional(),
  is_recurring: z.boolean().optional(),
};

function hasHolidaySchedule(value: {
  dates?: string[];
  recurring_weekdays?: number[];
  date?: string;
}) {
  return Boolean(
    (value.dates && value.dates.length > 0) ||
    (value.recurring_weekdays && value.recurring_weekdays.length > 0) ||
    value.date,
  );
}

export const CreateHolidaySchema = z
  .object({
    branch_id: z.string().optional(),
    ...holidayFields,
    idempotency_key: z.string().trim().min(8).max(200).optional(),
  })
  .refine(hasHolidaySchedule, {
    message: 'Add at least one date or recurring weekday',
    path: ['dates'],
  });

export const UpdateHolidaySchema = z
  .object({
    ...holidayFields,
    name: holidayFields.name.optional(),
  })
  .refine(
    (value) =>
      value.dates !== undefined ||
      value.recurring_weekdays !== undefined ||
      value.date !== undefined ||
      value.end_date !== undefined ||
      value.name !== undefined ||
      value.is_recurring !== undefined,
    { message: 'At least one holiday field is required' },
  );

export type CreateHolidayInput = z.infer<typeof CreateHolidaySchema>;
export type UpdateHolidayInput = z.infer<typeof UpdateHolidaySchema>;

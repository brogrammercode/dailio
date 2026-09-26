import { z } from 'zod';

const EvidenceSchema = z.object({
  storage_key: z.string().trim().min(1).max(500),
  content_type: z.string().trim().min(1).max(120),
  size_bytes: z.number().int().positive().max(20_000_000).optional(),
  reference: z.string().trim().max(200).optional(),
  note: z.string().trim().max(1000).optional(),
});

const PaymentRequestStatusSchema = z.enum([
  'REQUESTED',
  'NEEDS_INFORMATION',
  'APPROVED',
  'REJECTED',
  'CANCELLED',
]);

export const PaymentRequestPeriodSchema = z.enum([
  'today',
  'yesterday',
  'this_week',
  'this_month',
  'this_year',
]);

export const CreatePaymentRequestSchema = z.object({
  subscription_id: z.string().min(1),
  amount_minor_unit: z.number().int().positive(),
  currency: z
    .string()
    .length(3)
    .transform((value) => value.toUpperCase())
    .default('INR'),
  method: z.enum(['CASH', 'UPI', 'CARD', 'BANK_TRANSFER', 'GATEWAY']),
  reference: z.string().trim().max(200).optional(),
  note: z.string().trim().max(1000).optional(),
  evidence: z.array(EvidenceSchema).max(5).default([]),
});

export const ReviewPaymentRequestSchema = z.object({
  reason: z.string().trim().max(1000).optional(),
});

export const PaymentRequestQuerySchema = z.object({
  status: PaymentRequestStatusSchema.optional(),
  period: PaymentRequestPeriodSchema.optional(),
});

export const PaymentEvidenceUploadSchema = z.object({
  filename: z.string().trim().min(1).max(200),
  content_type: z.enum(['image/jpeg', 'image/png', 'image/webp', 'application/pdf']),
});

export const PaymentCorrectionSchema = z.object({
  reason: z.string().trim().min(1).max(1000),
});

export const FeeQuerySchema = z.object({
  period: z.enum(['this_month', 'last_month', 'custom']).default('this_month'),
  from: z.string().date().optional(),
  to: z.string().date().optional(),
  status: z
    .enum(['PAID', 'REQUESTED', 'PENDING', 'PARTIALLY_PAID', 'EXPIRING_SOON', 'EXPIRED'])
    .optional(),
  member_id: z.string().optional(),
  page: z.coerce.number().int().positive().default(1),
  limit: z.coerce.number().int().positive().max(100).default(50),
});

export type CreatePaymentRequestInput = z.infer<typeof CreatePaymentRequestSchema>;
export type ReviewPaymentRequestInput = z.infer<typeof ReviewPaymentRequestSchema>;
export type PaymentRequestQuery = z.infer<typeof PaymentRequestQuerySchema>;
export type PaymentRequestPeriod = z.infer<typeof PaymentRequestPeriodSchema>;
export type PaymentEvidenceUploadInput = z.infer<typeof PaymentEvidenceUploadSchema>;
export type PaymentCorrectionInput = z.infer<typeof PaymentCorrectionSchema>;
export type FeeQuery = z.infer<typeof FeeQuerySchema>;

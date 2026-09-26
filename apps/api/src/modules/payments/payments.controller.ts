import type { NextFunction, Request, Response } from 'express';

import { ForbiddenError, ValidationError } from '../../lib/errors';

import {
  CreatePaymentRequestSchema,
  FeeQuerySchema,
  PaymentEvidenceUploadSchema,
  PaymentCorrectionSchema,
  PaymentRequestQuerySchema,
  ReviewPaymentRequestSchema,
} from './payments.schema';
import * as paymentsService from './payments.service';

function idempotencyKey(req: Request) {
  const value = req.header('Idempotency-Key');
  if (!value?.trim()) throw new ValidationError('Idempotency-Key header is required');
  return value.trim();
}

export async function createPaymentRequest(req: Request, res: Response, next: NextFunction) {
  try {
    const body = CreatePaymentRequestSchema.parse(req.body);
    const request = await paymentsService.createPaymentRequest(
      req.user!.id,
      req.organization!.id,
      req.branch!.id,
      idempotencyKey(req),
      body,
    );
    res.status(201).json({ data: request });
  } catch (error) {
    next(error);
  }
}

export async function createEvidenceUploadSignature(
  req: Request,
  res: Response,
  next: NextFunction,
) {
  try {
    const input = PaymentEvidenceUploadSchema.parse(req.body);
    const signature = paymentsService.createPaymentEvidenceUploadSignature(
      req.organization!.id,
      input.filename,
    );
    res.json({ data: signature });
  } catch (error) {
    next(error);
  }
}

export async function listPaymentRequests(req: Request, res: Response, next: NextFunction) {
  try {
    const { status, period } = PaymentRequestQuerySchema.parse(req.query);
    const requests = await paymentsService.listPaymentRequests(
      req.organization!.id,
      req.branch!.id,
      req.permissions ?? new Set<string>(),
      req.member!.id,
      status,
      period,
    );
    res.json({ data: requests });
  } catch (error) {
    next(error);
  }
}

export async function getPaymentRequest(req: Request, res: Response, next: NextFunction) {
  try {
    const request = await paymentsService.getPaymentRequest(
      req.organization!.id,
      req.branch!.id,
      req.params.request_id,
      req.permissions ?? new Set<string>(),
      req.member!.id,
    );
    res.json({ data: request });
  } catch (error) {
    next(error);
  }
}

export async function reviewPaymentRequest(req: Request, res: Response, next: NextFunction) {
  try {
    if (!['approve', 'reject', 'needs_information'].includes(req.params.action)) {
      throw new ValidationError('Payment request action is invalid');
    }
    const action = req.params.action as 'approve' | 'reject' | 'needs_information';
    const body = ReviewPaymentRequestSchema.parse(req.body);
    if (action !== 'approve' && !body.reason) {
      throw new ValidationError('A reason is required for rejection or more information requests');
    }
    const request = await paymentsService.reviewPaymentRequest(
      req.user!.id,
      req.organization!.id,
      req.branch!.id,
      req.params.request_id,
      action,
      body,
    );
    res.json({ data: request });
  } catch (error) {
    next(error);
  }
}

export async function correctPayment(req: Request, res: Response, next: NextFunction) {
  try {
    const action = req.params.action;
    if (action !== 'refund' && action !== 'void')
      throw new ValidationError('Payment correction action is invalid');
    const permissions = req.permissions ?? new Set<string>();
    const requiredPermission = action === 'refund' ? 'PAYMENT_REFUND' : 'PAYMENT_VOID';
    if (!permissions.has('ALL') && !permissions.has(requiredPermission))
      throw new ForbiddenError('Payment correction is not permitted');
    const body = PaymentCorrectionSchema.parse(req.body);
    const entry = await paymentsService.correctPayment(
      req.user!.id,
      req.organization!.id,
      req.branch!.id,
      req.params.payment_attempt_id,
      action,
      body,
    );
    res.json({ data: entry });
  } catch (error) {
    next(error);
  }
}

export async function getReceipt(req: Request, res: Response, next: NextFunction) {
  try {
    const receipt = await paymentsService.getReceipt(
      req.organization!.id,
      req.branch!.id,
      req.params.payment_attempt_id,
      req.permissions ?? new Set<string>(),
      req.member!.id,
    );
    res.json({ data: receipt });
  } catch (error) {
    next(error);
  }
}

export async function getEvidenceDownloadUrl(req: Request, res: Response, next: NextFunction) {
  try {
    const result = await paymentsService.getEvidenceDownloadUrl(
      req.organization!.id,
      req.branch!.id,
      req.params.request_id,
      req.params.evidence_id,
      req.permissions ?? new Set<string>(),
      req.member!.id,
    );
    res.json({ data: result });
  } catch (error) {
    next(error);
  }
}

export async function listFees(req: Request, res: Response, next: NextFunction) {
  try {
    const query = FeeQuerySchema.parse(req.query);
    const result = await paymentsService.listFees(
      req.organization!.id,
      req.branch!.id,
      req.permissions ?? new Set<string>(),
      query,
      req.member!.id,
    );
    res.json(result);
  } catch (error) {
    next(error);
  }
}

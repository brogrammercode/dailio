import type { Request, Response, NextFunction } from 'express';

import { ValidationError } from '../../lib/errors';

import {
  AttendanceEvidenceUploadSchema,
  ClockInSchema,
  ClockOutSchema,
  CorrectSessionSchema,
  CreateManualSessionSchema,
  ListSessionsQuerySchema,
  UpdatePolicySchema,
} from './attendance.schema';
import * as attendanceService from './attendance.service';

export async function clockInHandler(req: Request, res: Response, next: NextFunction) {
  try {
    const body = ClockInSchema.parse({ body: req.body }).body;
    const idempotencyKey = req.header('Idempotency-Key')?.trim();
    if (!idempotencyKey) throw new ValidationError('Idempotency-Key header is required');
    const session = await attendanceService.clockIn(
      req.user!.id,
      req.organization!.id,
      req.branch!.id,
      { ...body, idempotency_key: idempotencyKey },
    );
    res.status(201).json({ data: session, server_time: new Date().toISOString() });
  } catch (error) {
    next(error);
  }
}

export async function createEvidenceUploadSignatureHandler(
  req: Request,
  res: Response,
  next: NextFunction,
) {
  try {
    const input = AttendanceEvidenceUploadSchema.parse(req.body);
    const signature = attendanceService.createAttendanceSelfieUploadSignature(
      req.user!.id,
      req.organization!.id,
      req.branch!.id,
      input.filename,
    );
    res.json({ data: signature });
  } catch (error) {
    next(error);
  }
}

export async function clockOutHandler(req: Request, res: Response, next: NextFunction) {
  try {
    const body = ClockOutSchema.parse({ body: req.body }).body;
    const idempotencyKey = req.header('Idempotency-Key')?.trim();
    if (!idempotencyKey) throw new ValidationError('Idempotency-Key header is required');

    const permissions = req.permissions || new Set<string>();

    const session = await attendanceService.clockOut(
      req.user!.id,
      req.organization!.id,
      req.branch!.id,
      { ...body, idempotency_key: idempotencyKey },
      permissions,
    );
    res.json({ data: session, server_time: new Date().toISOString() });
  } catch (error) {
    next(error);
  }
}

export async function createManualSessionHandler(req: Request, res: Response, next: NextFunction) {
  try {
    const body = CreateManualSessionSchema.parse({ body: req.body }).body;
    const idempotencyKey = req.header('Idempotency-Key')?.trim();
    if (!idempotencyKey) throw new ValidationError('Idempotency-Key header is required');
    const session = await attendanceService.createManualSession(
      req.user!.id,
      req.organization!.id,
      req.branch!.id,
      { ...body, idempotency_key: idempotencyKey },
      req.permissions || new Set<string>(),
    );
    res.status(201).json({ data: session, server_time: new Date().toISOString() });
  } catch (error) {
    next(error);
  }
}

export async function activeSessionHandler(req: Request, res: Response, next: NextFunction) {
  try {
    const session = await attendanceService.getActiveSession(
      req.user!.id,
      req.organization!.id,
      req.branch!.id,
      req.permissions ?? new Set<string>(),
    );
    res.json({ session, server_time: new Date().toISOString() });
  } catch (error) {
    next(error);
  }
}

export async function listSessionsHandler(req: Request, res: Response, next: NextFunction) {
  try {
    const query = ListSessionsQuerySchema.parse({ query: req.query }).query;
    const permissions = req.permissions || new Set<string>();
    const result = await attendanceService.listSessionsPage(
      req.user!.id,
      req.organization!.id,
      req.branch!.id,
      query,
      permissions,
    );
    res.json({
      data: result.data,
      meta: { next_cursor: result.next_cursor },
      server_time: new Date().toISOString(),
    });
  } catch (error) {
    next(error);
  }
}

export async function exportSessionsHandler(req: Request, res: Response, next: NextFunction) {
  try {
    const query = ListSessionsQuerySchema.parse({ query: req.query }).query;
    const csv = await attendanceService.exportSessions(
      req.user!.id,
      req.organization!.id,
      req.branch!.id,
      query,
      req.permissions || new Set<string>(),
    );
    res
      .status(200)
      .type('text/csv')
      .setHeader('Content-Disposition', 'attachment; filename="dailio-attendance.csv"')
      .send(csv);
  } catch (error) {
    next(error);
  }
}

export async function getSessionDetailHandler(req: Request, res: Response, next: NextFunction) {
  try {
    const permissions = req.permissions || new Set<string>();
    const session = await attendanceService.getSessionDetail(
      req.user!.id,
      req.organization!.id,
      req.branch!.id,
      req.params.session_id,
      permissions,
    );
    res.json({ data: session });
  } catch (error) {
    next(error);
  }
}

export async function getEvidenceDownloadUrlHandler(
  req: Request,
  res: Response,
  next: NextFunction,
) {
  try {
    const result = await attendanceService.getEvidenceDownloadUrl(
      req.user!.id,
      req.organization!.id,
      req.branch!.id,
      req.params.session_id,
      req.params.evidence_id,
      req.permissions ?? new Set<string>(),
    );
    res.json({ data: result });
  } catch (error) {
    next(error);
  }
}

export async function getPolicyHandler(req: Request, res: Response, next: NextFunction) {
  try {
    const policy = await attendanceService.getPolicy(
      req.organization!.id,
      req.branch!.id,
      req.user!.id,
      req.permissions ?? new Set<string>(),
      typeof req.query.member_id === 'string' ? req.query.member_id : undefined,
    );
    res.status(200).json({ data: policy, server_time: new Date().toISOString() });
  } catch (error) {
    next(error);
  }
}

export async function listPoliciesHandler(req: Request, res: Response, next: NextFunction) {
  try {
    const policies = await attendanceService.listPolicies(
      req.organization!.id,
      req.branch!.id,
      req.permissions ?? new Set<string>(),
    );
    res.json({ data: policies });
  } catch (error) {
    next(error);
  }
}

export async function updatePolicyHandler(req: Request, res: Response, next: NextFunction) {
  try {
    const body = UpdatePolicySchema.parse({ body: req.body }).body;
    const policy = await attendanceService.updatePolicy(
      req.user!.id,
      req.organization!.id,
      req.branch!.id,
      body,
      req.permissions ?? new Set<string>(),
    );
    res.status(200).json({ data: policy });
  } catch (error) {
    next(error);
  }
}

export async function correctSessionHandler(req: Request, res: Response, next: NextFunction) {
  try {
    const session_id = req.params.session_id;
    const body = CorrectSessionSchema.parse({ body: req.body }).body;

    const session = await attendanceService.correctSession(
      req.user!.id,
      req.organization!.id,
      req.branch!.id,
      session_id,
      body,
      req.permissions ?? new Set<string>(),
    );

    res.status(200).json({ data: session });
  } catch (error) {
    next(error);
  }
}

import type { Request, Response, NextFunction } from 'express';

import { ClockInSchema, ClockOutSchema, ListSessionsQuerySchema } from './attendance.schema';
import * as attendanceService from './attendance.service';

export async function clockInHandler(req: Request, res: Response, next: NextFunction) {
  try {
    const body = ClockInSchema.parse({ body: req.body }).body;
    const session = await attendanceService.clockIn(
      req.user!.id,
      req.organization!.id,
      req.branch!.id,
      body
    );
    res.status(201).json({ data: session });
  } catch (error) {
    next(error);
  }
}

export async function clockOutHandler(req: Request, res: Response, next: NextFunction) {
  try {
    const body = ClockOutSchema.parse({ body: req.body }).body;
    
    // Pass permissions if we decide to implement ATTENDANCE_CREATE_ALL check inside the service
    // For now we'll do a basic implementation since we aren't passing permissions in the instruction signature
    // except for listSessions. Let's adjust clockOut if needed.

    // Check permissions
    const permissions = req.permissions || new Set<string>();
    
    // We should ideally pass permissions to clockOut to check ATTENDANCE_CREATE_ALL.
    // For now we update the service signature in thought, or just implement it. 
    // Let's implement it in controller before calling service or pass it.
    // I'll update the service slightly to accept permissions or handle it.
    // Actually the instruction for clockOut didn't specify passing permissions explicitly in signature, but said "Verify the session belongs to the calling user's membership (unless they have ATTENDANCE_CREATE_ALL)".
    
    const session = await attendanceService.clockOut(
      req.user!.id,
      req.organization!.id,
      req.branch!.id,
      body,
      permissions
    );
    res.json({ data: session });
  } catch (error) {
    next(error);
  }
}

export async function activeSessionHandler(req: Request, res: Response, next: NextFunction) {
  try {
    const session = await attendanceService.getActiveSession(
      req.user!.id,
      req.organization!.id,
      req.branch!.id
    );
    res.json({ session });
  } catch (error) {
    next(error);
  }
}

export async function listSessionsHandler(req: Request, res: Response, next: NextFunction) {
  try {
    const query = ListSessionsQuerySchema.parse({ query: req.query }).query;
    const permissions = req.permissions || new Set<string>();
    const data = await attendanceService.listSessions(
      req.user!.id,
      req.organization!.id,
      req.branch!.id,
      query,
      permissions
    );
    res.json({ data });
  } catch (error) {
    next(error);
  }
}

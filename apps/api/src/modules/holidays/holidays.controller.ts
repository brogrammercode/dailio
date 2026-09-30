import type { NextFunction, Request, Response } from 'express';

import { CreateHolidaySchema, UpdateHolidaySchema } from './holidays.schema';
import * as holidaysService from './holidays.service';

export async function listHolidays(req: Request, res: Response, next: NextFunction) {
  try {
    res.json({ data: await holidaysService.listHolidays(req.organization!.id, req.branch!.id) });
  } catch (error) {
    next(error);
  }
}

export async function createHoliday(req: Request, res: Response, next: NextFunction) {
  try {
    const input = CreateHolidaySchema.parse(req.body);
    res.status(201).json({
      data: await holidaysService.createHoliday(
        req.organization!.id,
        req.branch!.id,
        input,
        req.user!.id,
        req.header('Idempotency-Key') ?? undefined,
      ),
    });
  } catch (error) {
    next(error);
  }
}

export async function updateHoliday(req: Request, res: Response, next: NextFunction) {
  try {
    const input = UpdateHolidaySchema.parse(req.body);
    res.json({
      data: await holidaysService.updateHoliday(
        req.organization!.id,
        req.branch!.id,
        req.params.holiday_id,
        input,
        req.user!.id,
      ),
    });
  } catch (error) {
    next(error);
  }
}

export async function deleteHoliday(req: Request, res: Response, next: NextFunction) {
  try {
    await holidaysService.deleteHoliday(
      req.organization!.id,
      req.branch!.id,
      req.params.holiday_id,
      req.user!.id,
    );
    res.status(204).send();
  } catch (error) {
    next(error);
  }
}

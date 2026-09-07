import type { Request, Response, NextFunction } from 'express';

import { ListMembersQuerySchema, AssistedAdmissionSchema, MemberActionSchema } from './members.schema';
import * as membersService from './members.service';

export async function listMembers(req: Request, res: Response, next: NextFunction) {
  try {
    const query = ListMembersQuerySchema.parse({ query: req.query }).query;
    const result = await membersService.listMembers(
      req.organization!.id,
      req.location!.id,
      query
    );
    res.json(result);
  } catch (error) {
    next(error);
  }
}

export async function getMember(req: Request, res: Response, next: NextFunction) {
  try {
    const member = await membersService.getMemberDetail(
      req.organization!.id,
      req.location!.id,
      req.params.membership_id
    );
    res.json({ data: member });
  } catch (error) {
    next(error);
  }
}

export async function newAdmission(req: Request, res: Response, next: NextFunction) {
  try {
    const body = AssistedAdmissionSchema.parse({ body: req.body }).body;
    const member = await membersService.createAssistedAdmission(
      req.user!.id,
      req.organization!.id,
      req.location!.id,
      body
    );
    res.status(201).json({ data: member });
  } catch (error) {
    next(error);
  }
}

export async function suspend(req: Request, res: Response, next: NextFunction) {
  try {
    const body = MemberActionSchema.parse({ body: req.body }).body;
    const member = await membersService.suspendMember(
      req.user!.id,
      req.organization!.id,
      req.location!.id,
      req.params.membership_id,
      body
    );
    res.json({ data: member });
  } catch (error) {
    next(error);
  }
}

export async function deactivate(req: Request, res: Response, next: NextFunction) {
  try {
    const body = MemberActionSchema.parse({ body: req.body }).body;
    const member = await membersService.deactivateMember(
      req.user!.id,
      req.organization!.id,
      req.location!.id,
      req.params.membership_id,
      body
    );
    res.json({ data: member });
  } catch (error) {
    next(error);
  }
}

import type { Request, Response, NextFunction } from 'express';

import {
  ListMembersQuerySchema,
  AssistedAdmissionSchema,
  MemberActionSchema,
  UpdateMemberSchema,
} from './members.schema';
import * as membersService from './members.service';

export async function listMembers(req: Request, res: Response, next: NextFunction) {
  try {
    const parsed = ListMembersQuerySchema.parse({ query: req.query });
    const result = await membersService.listMembers(
      req.organization!.id,
      req.branch!.id,
      parsed.query,
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
      req.branch!.id,
      req.params.member_id,
    );
    res.json({ data: member });
  } catch (error) {
    next(error);
  }
}

export async function newAdmission(req: Request, res: Response, next: NextFunction) {
  try {
    const parsed = AssistedAdmissionSchema.parse({ body: req.body });
    const member = await membersService.createAssistedAdmission(
      req.user!.id,
      req.organization!.id,
      req.branch!.id,
      parsed.body,
    );
    res.status(201).json({ data: member });
  } catch (error) {
    next(error);
  }
}

export async function suspend(req: Request, res: Response, next: NextFunction) {
  try {
    const parsed = MemberActionSchema.parse({ body: req.body });
    const member = await membersService.suspendMember(
      req.user!.id,
      req.organization!.id,
      req.branch!.id,
      req.params.member_id,
      parsed.body,
    );
    res.json({ data: member });
  } catch (error) {
    next(error);
  }
}

export async function deactivate(req: Request, res: Response, next: NextFunction) {
  try {
    const parsed = MemberActionSchema.parse({ body: req.body });
    const member = await membersService.deactivateMember(
      req.user!.id,
      req.organization!.id,
      req.branch!.id,
      req.params.member_id,
      parsed.body,
    );
    res.json({ data: member });
  } catch (error) {
    next(error);
  }
}
export async function update(req: Request, res: Response, next: NextFunction) {
  try {
    const parsed = UpdateMemberSchema.parse({ body: req.body });
    const member = await membersService.updateMember(
      req.user!.id,
      req.organization!.id,
      req.branch!.id,
      req.params.member_id,
      parsed.body,
    );
    res.json({ data: member });
  } catch (error) {
    next(error);
  }
}
export async function getOrganizationMembers(req: Request, res: Response, next: NextFunction) {
  try {
    const orgId = req.params.organization_id;
    const branchId = req.query.branch_id as string | undefined;
    const result = await membersService.listOrganizationMembers(orgId, branchId);
    res.json(result);
  } catch (error) {
    next(error);
  }
}

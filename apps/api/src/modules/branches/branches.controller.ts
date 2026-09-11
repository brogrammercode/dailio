import { Request, Response, NextFunction } from 'express';
import { DiscoverBranchesQuerySchema, CreateBranchSchema, UpdateBranchSchema } from './branches.schema';
import { discoverBranches as discoverService, createBranch as createService, updateBranch as updateService, getBranchById as getBranchService } from './branches.service';

export async function discoverBranches(req: Request, res: Response, next: NextFunction) {
  try {
    const query = DiscoverBranchesQuerySchema.parse(req.query);
    const result = await discoverService(query);
    res.json(result);
  } catch (err) {
    next(err);
  }
}

export async function createBranch(req: Request, res: Response, next: NextFunction) {
  try {
    const orgId = req.params.organization_id;
    const data = CreateBranchSchema.parse(req.body);
    const result = await createService(orgId, data);
    res.status(201).json({ data: result });
  } catch (err) {
    next(err);
  }
}

export async function updateBranch(req: Request, res: Response, next: NextFunction) {
  try {
    const orgId = req.params.organization_id;
    const branchId = req.params.branch_id;
    const data = UpdateBranchSchema.parse(req.body);
    const result = await updateService(branchId, orgId, data);
    res.json({ data: result });
  } catch (err) {
    next(err);
  }
}
export async function getBranch(req: Request, res: Response, next: NextFunction) {
  try {
    const orgId = req.params.organization_id;
    const branchId = req.params.branch_id;
    const result = await getBranchService(branchId, orgId);
    if (!result) return res.status(404).json({ error: 'Branch not found' });
    res.json({ data: result });
  } catch (err) {
    next(err);
  }
}

export async function getOrganizationBranches(req: Request, res: Response, next: NextFunction) {
  try {
    const orgId = req.params.organization_id;
    const result = await require('./branches.service').getOrganizationBranches(orgId);
    res.json({ data: result });
  } catch (err) {
    next(err);
  }
}

import { Request, Response, NextFunction } from 'express';

import { listSalaryStructures, createSalaryStructure, updateSalaryStructure, deleteSalaryStructure } from './payroll.service';
import { CreateSalaryStructureSchema, UpdateSalaryStructureSchema } from './payroll.schema';

export async function listStructures(req: Request, res: Response, next: NextFunction) {
  try {
    const orgId = req.params.organization_id;
    const branchId = req.query.branch_id as string;
    const result = await listSalaryStructures(orgId, branchId);
    res.json({ data: result });
  } catch (err) { next(err); }
}
export async function createStructure(req: Request, res: Response, next: NextFunction) {
  try {
    const orgId = req.params.organization_id;
    const data = CreateSalaryStructureSchema.parse(req.body);
    const result = await createSalaryStructure(orgId, data);
    res.status(201).json({ data: result });
  } catch (err) { next(err); }
}
export async function updateStructure(req: Request, res: Response, next: NextFunction) {
  try {
    const orgId = req.params.organization_id;
    const data = UpdateSalaryStructureSchema.parse(req.body);
    const result = await updateSalaryStructure(orgId, req.params.id, data);
    res.json({ data: result });
  } catch (err) { next(err); }
}
export async function deleteStructure(req: Request, res: Response, next: NextFunction) {
  try {
    const orgId = req.params.organization_id;
    await deleteSalaryStructure(orgId, req.params.id);
    res.status(204).send();
  } catch (err) { next(err); }
}

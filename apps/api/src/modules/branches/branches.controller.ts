import type { Request, Response } from 'express';

import { DiscoverBranchesQuerySchema } from './branches.schema';
import * as branchesService from './branches.service';

export async function discoverBranches(req: Request, res: Response) {
  const query = DiscoverBranchesQuerySchema.parse(req.query);
  const result = await branchesService.discoverBranches(query);
  res.json(result);
}

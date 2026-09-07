import type { Request, Response } from 'express';

import { DiscoverLocationsQuerySchema } from './locations.schema';
import * as locationsService from './locations.service';

export async function discoverLocations(req: Request, res: Response) {
  const query = DiscoverLocationsQuerySchema.parse(req.query);
  const result = await locationsService.discoverLocations(query);
  res.json(result);
}

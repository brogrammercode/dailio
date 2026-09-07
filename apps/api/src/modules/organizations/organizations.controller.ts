import { NextFunction, Request, Response } from 'express';

import { CreateLocationSchema, CreateOrganizationSchema } from './organizations.schema';
import { createOrganizationWithFirstLocation, getOrganization, getUserOrganizations } from './organizations.service';

export async function createOrganization(req: Request, res: Response, next: NextFunction) {
  try {
    const organizationData = CreateOrganizationSchema.parse(req.body.organization);
    const locationData = CreateLocationSchema.parse(req.body.location);
    const result = await createOrganizationWithFirstLocation(req.user!.id, organizationData, locationData);
    res.status(201).json(result);
  } catch (err) {
    next(err);
  }
}

export async function listMyOrganizations(req: Request, res: Response, next: NextFunction) {
  try {
    const organizations = await getUserOrganizations(req.user!.id);
    res.status(200).json({ organizations });
  } catch (err) {
    next(err);
  }
}

export async function getOrganizationById(req: Request, res: Response, next: NextFunction) {
  try {
    const organization = await getOrganization(req.params.organization_id, req.user!.id);
    res.status(200).json({ organization });
  } catch (err) {
    next(err);
  }
}

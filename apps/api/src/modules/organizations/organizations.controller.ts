import { NextFunction, Request, Response } from 'express';

import { CreateLocationSchema, CreateOrganizationSchema, UpdateOrganizationSchema } from './organizations.schema';
import { createOrganizationWithFirstLocation, getOrganization, getUserOrganizations, updateOrganization as updateOrgService } from './organizations.service';

import { cloudinary } from '../../lib/cloudinary';

export async function createOrganization(req: Request, res: Response, next: NextFunction) {
  try {
    const orgPayload = CreateOrganizationSchema.parse(req.body.organization);
    const locationData = CreateLocationSchema.parse(req.body.location);
    
    const { logo_base64, ...organizationData } = orgPayload;
    let logo_url: string | undefined = undefined;

    if (logo_base64) {
      const uploadResult = await cloudinary.uploader.upload(logo_base64, {
        folder: 'organizations/logos',
      });
      logo_url = uploadResult.secure_url;
    }

    const finalOrgData = { ...organizationData, logo_url };
    const result = await createOrganizationWithFirstLocation(req.user!.id, finalOrgData, locationData);
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

export async function updateOrganization(req: Request, res: Response, next: NextFunction) {
  try {
    const payload = UpdateOrganizationSchema.parse(req.body);
    const { logo_base64, ...organizationData } = payload;
    let logo_url: string | undefined = undefined;

    if (logo_base64) {
      const uploadResult = await cloudinary.uploader.upload(logo_base64, {
        folder: 'organizations/logos',
      });
      logo_url = uploadResult.secure_url;
    }

    const finalData = { ...organizationData, ...(logo_url && { logo_url }) };
    const organization = await updateOrgService(req.params.organization_id, req.user!.id, finalData);
    res.status(200).json({ organization });
  } catch (err) {
    next(err);
  }
}


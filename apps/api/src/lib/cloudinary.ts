import { v2 as cloudinary } from 'cloudinary';

import { env } from '../config/env';

// Configure Cloudinary globally
cloudinary.config({
  cloud_name: env.CLOUDINARY_CLOUD_NAME,
  api_key: env.CLOUDINARY_API_KEY,
  api_secret: env.CLOUDINARY_API_SECRET,
  secure: true,
});

export { cloudinary };

/**
 * Generate a signed upload payload for direct-to-Cloudinary client-side uploads.
 */
export function getUploadSignature(folder: string, publicId?: string) {
  const timestamp = Math.round(new Date().getTime() / 1000);
  const paramsToSign: Record<string, unknown> = {
    timestamp,
    folder,
  };

  if (publicId) {
    paramsToSign.public_id = publicId;
  }

  const signature = cloudinary.utils.api_sign_request(
    paramsToSign,
    env.CLOUDINARY_API_SECRET ?? '',
  );

  return {
    timestamp,
    signature,
    api_key: env.CLOUDINARY_API_KEY,
    cloud_name: env.CLOUDINARY_CLOUD_NAME,
    folder,
    public_id: publicId,
  };
}

/**
 * Build a structured folder path for Cloudinary.
 */
export function buildStorageKey(organization_id: string, category: string, filename: string): string {
  // Strip extension for the public_id as Cloudinary handles extensions via format
  const baseFilename = filename.split('.')[0];
  return `organizations/${organization_id}/${category}/${baseFilename}`;
}

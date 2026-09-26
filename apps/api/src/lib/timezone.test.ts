import { describe, expect, it } from 'vitest';

import { CreateBranchSchema } from '../modules/branches/branches.schema';
import {
  CreateLocationSchema,
  CreateOrganizationSchema,
} from '../modules/organizations/organizations.schema';

import { isValidIanaTimezone } from './timezone';

describe('IANA timezone validation', () => {
  it('accepts branch-supported timezone identifiers', () => {
    expect(isValidIanaTimezone('Asia/Kolkata')).toBe(true);
    expect(isValidIanaTimezone('America/New_York')).toBe(true);
    expect(isValidIanaTimezone('UTC')).toBe(true);
  });

  it('rejects malformed timezone identifiers', () => {
    expect(isValidIanaTimezone('not-a-timezone')).toBe(false);
    expect(isValidIanaTimezone('')).toBe(false);
  });

  it('rejects malformed timezones at organization and branch boundaries', () => {
    expect(
      CreateOrganizationSchema.safeParse({ name: 'Dailio', timezone: 'not-a-timezone' }).success,
    ).toBe(false);
    expect(
      CreateLocationSchema.safeParse({ name: 'Main branch', timezone: 'not-a-timezone' }).success,
    ).toBe(false);
    expect(
      CreateBranchSchema.safeParse({ name: 'Main branch', timezone: 'not-a-timezone' }).success,
    ).toBe(false);
  });
});

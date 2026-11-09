import type { Request, Response, NextFunction } from 'express';
import { beforeEach, expect, it, vi } from 'vitest';

const project = vi.hoisted(() => vi.fn());
vi.mock('../modules/members/profile-presentation.service', () => ({
  presentOrganizationProfiles: project,
}));
import { organizationProfilePresentation } from './organizationProfilePresentation';

beforeEach(() => vi.resetAllMocks());
it('reads organization context resolved later by authorization middleware', async () => {
  const req = { method: 'GET' } as Request;
  const json = vi.fn();
  const next = vi.fn();
  const res = { statusCode: 200, json } as unknown as Response;
  organizationProfilePresentation(req, res, next as NextFunction);
  Object.assign(req, { organization: { id: 'authorized-org' } });
  project.mockResolvedValue({ data: 'projected' });
  res.json({ data: 'original' });
  await Promise.resolve();
  expect(project).toHaveBeenCalledWith('authorized-org', { data: 'original' });
  expect(json).toHaveBeenCalledWith({ data: 'projected' });
});
it.each([
  { method: 'GET', status: 403, org: true },
  { method: 'POST', status: 200, org: true },
  { method: 'GET', status: 200, org: false },
])(
  'leaves forbidden, global, and mutation responses untouched: %j',
  async ({ method, status, org }) => {
    const req = { method, ...(org ? { organization: { id: 'org' } } : {}) } as Request;
    const json = vi.fn();
    const res = { statusCode: status, json } as unknown as Response;
    organizationProfilePresentation(req, res, vi.fn());
    res.json({ data: 'original' });
    expect(project).not.toHaveBeenCalled();
    expect(json).toHaveBeenCalledWith({ data: 'original' });
  },
);

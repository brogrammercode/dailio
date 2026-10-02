import { apiRequest } from "../../lib/api-client";
import type { TenantContext } from "../../types/domain";

export function contextFromInvite(invite: {
  organization: { id: string; name: string };
  branch: { id: string; name: string; timezone: string };
}): TenantContext {
  return {
    organizationId: invite.organization.id,
    organizationName: invite.organization.name,
    branchId: invite.branch.id,
    branchName: invite.branch.name,
    timezone: invite.branch.timezone,
  };
}

export async function discoverBranches(query?: string) {
  const body = await apiRequest<{ data: unknown[] }>(
    `/branches/discover${query ? `?query=${encodeURIComponent(query)}` : ""}`,
  );
  return body.data;
}

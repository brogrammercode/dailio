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

type MemberContext = {
  organization_id: string;
  branch_id: string;
  status: string;
  effective_permissions?: string[];
  organization: { id: string; name: string; status: string; type: string };
  branch: {
    id: string;
    organization_id: string;
    name: string;
    timezone: string;
    status: string;
  } | null;
};

export async function getMemberContexts(): Promise<TenantContext[]> {
  const body = await apiRequest<{ contexts: MemberContext[] }>("/me/contexts");
  return body.contexts
    .filter(
      (member) =>
        member.status === "ACTIVE" &&
        member.organization?.status === "ACTIVE" &&
        member.branch?.status === "ACTIVE" &&
        member.organization.id === member.organization_id &&
        member.branch.organization_id === member.organization_id &&
        member.branch.id === member.branch_id,
    )
    .map((member) => ({
      organizationId: member.organization_id,
      organizationName: member.organization.name,
      organizationType: member.organization.type,
      branchId: member.branch_id,
      branchName: member.branch!.name,
      timezone: member.branch!.timezone,
      permissions: member.effective_permissions ?? [],
    }));
}

export async function discoverBranches(query?: string) {
  const body = await apiRequest<{ data: unknown[] }>(
    `/branches/discover${query ? `?query=${encodeURIComponent(query)}` : ""}`,
  );
  return body.data;
}

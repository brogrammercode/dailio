import { beforeEach, describe, expect, it, vi } from "vitest";
import { apiRequest } from "../../lib/api-client";
import { getMemberContexts } from "./branches.api";

vi.mock("../../lib/api-client", () => ({ apiRequest: vi.fn() }));

const request = vi.mocked(apiRequest);
const active = {
  organization_id: "org-a",
  branch_id: "branch-a",
  status: "ACTIVE",
  organization: { id: "org-a", name: "Gym A", status: "ACTIVE" },
  branch: {
    id: "branch-a",
    organization_id: "org-a",
    name: "Main",
    timezone: "Asia/Kolkata",
    status: "ACTIVE",
  },
};

beforeEach(() => request.mockReset());

describe("member context restoration", () => {
  it("uses only active memberships with matching tenant and branch ownership", async () => {
    request.mockResolvedValue({
      contexts: [
        active,
        { ...active, status: "SUSPENDED" },
        {
          ...active,
          organization: { ...active.organization, status: "ARCHIVED" },
        },
        { ...active, branch: { ...active.branch, status: "ARCHIVED" } },
        { ...active, branch: { ...active.branch, organization_id: "org-b" } },
        { ...active, branch: null },
      ],
    });
    await expect(getMemberContexts()).resolves.toEqual([
      {
        organizationId: "org-a",
        organizationName: "Gym A",
        branchId: "branch-a",
        branchName: "Main",
        timezone: "Asia/Kolkata",
      },
    ]);
    expect(request).toHaveBeenCalledWith("/me/contexts");
  });
});

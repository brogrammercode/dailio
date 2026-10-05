// @vitest-environment jsdom
import { act } from "react";
import { createRoot, type Root } from "react-dom/client";
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";

import { setContext } from "../../lib/session";
import { MemberFeesPage } from "./MemberFeesPage";

const mocks = vi.hoisted(() => ({
  listFees: vi.fn(),
  createSettlementWaiver: vi.fn(),
  listSettlementWaivers: vi.fn(),
  reverseSettlementWaiver: vi.fn(),
}));
vi.mock("./payments.api", () => ({ ...mocks }));

let host: HTMLDivElement;
let root: Root;
async function settle() {
  await act(async () => {
    await new Promise((resolve) => setTimeout(resolve, 0));
  });
}

beforeEach(() => {
  Object.assign(globalThis, { IS_REACT_ACT_ENVIRONMENT: true });
  sessionStorage.clear();
  vi.clearAllMocks();
  mocks.listFees.mockResolvedValue([
    {
      member: { id: "member-1", name: "Riya" },
      subscription: { id: "sub-1", plan_name: "Monthly" },
      status: "PARTIALLY_PAID",
      charged_amount_minor_unit: 150000,
      paid_amount_minor_unit: 120000,
      waived_amount_minor_unit: 0,
      balance_minor_unit: 30000,
      currency: "INR",
    },
  ]);
  mocks.createSettlementWaiver.mockResolvedValue({ data: { id: "waiver-1" } });
  mocks.listSettlementWaivers.mockResolvedValue({
    data: [
      {
        id: "waiver-1",
        amount_minor_unit: 30000,
        currency: "INR",
        reason: "Negotiated final settlement",
        approved_by: "owner",
        created_at: "2026-10-04T00:00:00Z",
        reversal_id: null,
        reversed_at: null,
      },
    ],
    meta: { page: 1, limit: 20, total: 1 },
  });
  mocks.reverseSettlementWaiver.mockResolvedValue({
    data: { id: "reversal-1" },
  });
  host = document.createElement("div");
  document.body.appendChild(host);
  root = createRoot(host);
});
afterEach(async () => {
  await act(async () => root.unmount());
  host.remove();
});

async function render(permissions: string[]) {
  setContext({ organizationId: "org-1", branchId: "branch-1", permissions });
  await act(async () => root.render(<MemberFeesPage onBuy={() => {}} />));
  await settle();
}

describe("fee settlement UI", () => {
  it("shows separate paid, waived and due facts without exposing waiver to a member", async () => {
    await render(["PAYMENT_READ_SELF"]);
    expect(host.textContent).toContain("Charged");
    expect(host.textContent).toContain("Waived");
    expect(host.textContent).not.toContain("Settle by waiver");
    const history = [...host.querySelectorAll("button")].find(
      (item) => item.textContent === "View waiver history",
    );
    await act(async () => history?.click());
    await settle();
    expect(host.textContent).toContain("Negotiated final settlement");
    expect(host.textContent).not.toContain("Reverse waiver");
  });

  it("requires explicit confirmation before an authorized concession", async () => {
    await render(["PAYMENT_WAIVE"]);
    const open = [...host.querySelectorAll("button")].find(
      (item) => item.textContent === "Settle by waiver",
    );
    await act(async () => open?.click());
    const reason = host.querySelector("textarea") as HTMLTextAreaElement;
    await act(async () => {
      Object.getOwnPropertyDescriptor(
        HTMLTextAreaElement.prototype,
        "value",
      )?.set?.call(reason, "Negotiated final settlement");
      reason.dispatchEvent(new Event("input", { bubbles: true }));
    });
    const post = [...host.querySelectorAll("button")].find(
      (item) => item.textContent === "Post waiver",
    );
    await act(async () => post?.click());
    expect(mocks.createSettlementWaiver).not.toHaveBeenCalled();
    expect(host.querySelector('[role="dialog"]')).not.toBeNull();
    const confirm = host.querySelector(
      '[role="dialog"] button.primary-button',
    ) as HTMLButtonElement;
    await act(async () => confirm.click());
    await settle();
    expect(mocks.createSettlementWaiver).toHaveBeenCalledWith(
      "branch-1",
      "sub-1",
      30000,
      "Negotiated final settlement",
    );
  });

  it("keeps a settled waiver visible and requires a reason before reversal", async () => {
    mocks.listFees.mockResolvedValueOnce([
      {
        subscription: { id: "sub-1", plan_name: "Monthly" },
        status: "SETTLED",
        charged_amount_minor_unit: 150000,
        paid_amount_minor_unit: 120000,
        waived_amount_minor_unit: 30000,
        balance_minor_unit: 0,
        currency: "INR",
      },
    ]);
    await render(["PAYMENT_WAIVE"]);
    expect(host.textContent).not.toContain("Settle by waiver");
    const history = [...host.querySelectorAll("button")].find(
      (item) => item.textContent === "View waiver history",
    );
    await act(async () => history?.click());
    await settle();
    expect(host.textContent).toContain("Negotiated final settlement");
    const reverse = [...host.querySelectorAll("button")].find(
      (item) => item.textContent === "Reverse waiver",
    );
    await act(async () => reverse?.click());
    const confirm = host.querySelector(
      '[role="dialog"] button.primary-button',
    ) as HTMLButtonElement;
    expect(confirm.disabled).toBe(true);
    const reason = host.querySelector(
      '[role="dialog"] textarea',
    ) as HTMLTextAreaElement;
    await act(async () => {
      Object.getOwnPropertyDescriptor(
        HTMLTextAreaElement.prototype,
        "value",
      )?.set?.call(reason, "Correction after review");
      reason.dispatchEvent(new Event("input", { bubbles: true }));
    });
    expect(confirm.disabled).toBe(false);
    await act(async () => confirm.click());
    await settle();
    expect(mocks.reverseSettlementWaiver).toHaveBeenCalledWith(
      "branch-1",
      "sub-1",
      "waiver-1",
      "Correction after review",
    );
  });
});

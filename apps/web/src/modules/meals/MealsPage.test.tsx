// @vitest-environment jsdom
import { act } from "react";
import { createRoot, type Root } from "react-dom/client";
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";

import { setContext } from "../../lib/session";
import { MealsPage } from "./MealsPage";

const mocks = vi.hoisted(() => ({
  listMealSlots: vi.fn(),
  listMealServings: vi.fn(),
  getMealSummary: vi.fn(),
  searchMealMembers: vi.fn(),
  getMealEligibility: vi.fn(),
  serveMeal: vi.fn(),
  listMealPlans: vi.fn(),
  listMealEntitlements: vi.fn(),
}));
vi.mock("./meals.api", () => ({
  ...mocks,
  saveMealSlot: vi.fn(),
  setMealEntitlement: vi.fn(),
  voidMeal: vi.fn(),
}));

let host: HTMLDivElement;
let root: Root;
const slot = {
  id: "slot-1",
  code: "lunch",
  name: "Lunch",
  starts_at_local: "12:00",
  ends_at_local: "15:00",
  is_active: true,
};

async function settle() {
  await act(async () => {
    await new Promise((resolve) => setTimeout(resolve, 0));
  });
}

beforeEach(() => {
  Object.assign(globalThis, { IS_REACT_ACT_ENVIRONMENT: true });
  sessionStorage.clear();
  vi.clearAllMocks();
  mocks.listMealSlots.mockResolvedValue([slot]);
  mocks.listMealServings.mockResolvedValue({
    data: [],
    meta: { total: 0, page: 1, limit: 30 },
  });
  mocks.getMealSummary.mockResolvedValue({
    from: "2026-09-05",
    to: "2026-10-04",
    member_id: null,
    total: 0,
    slots: [{ meal_slot_id: "slot-1", name: "Lunch", code: "lunch", count: 0 }],
  });
  mocks.searchMealMembers.mockResolvedValue([
    { id: "member-1", member_number: "101", user: { name: "Riya" } },
  ]);
  mocks.getMealEligibility.mockResolvedValue({
    entitled: true,
    eligible: true,
    window_open: true,
    served_count: 0,
    remaining: 1,
    max_servings_per_day: 1,
  });
  mocks.serveMeal.mockResolvedValue({ id: "serving-1" });
  mocks.listMealPlans.mockResolvedValue([]);
  mocks.listMealEntitlements.mockResolvedValue([]);
  host = document.createElement("div");
  document.body.appendChild(host);
  root = createRoot(host);
});

afterEach(async () => {
  await act(async () => root.unmount());
  host.remove();
});

async function render(permissions: string[]) {
  setContext({
    organizationId: "org-1",
    branchId: "branch-1",
    branchName: "Mess A",
    organizationName: "Mess",
    organizationType: "FOOD_SERVICE",
    permissions,
  });
  await act(async () => root.render(<MealsPage />));
  await settle();
}

describe("meal UI permissions and serving", () => {
  it("shows only own history to a member", async () => {
    await render(["MEAL_READ_SELF"]);
    expect(host.textContent).toContain("Lunch");
    expect(host.textContent).toContain("Total confirmed: 0");
    expect(host.querySelector('[role="tablist"]')?.textContent).toContain(
      "History",
    );
    expect(host.querySelector('[role="tablist"]')?.textContent).not.toContain(
      "Serve",
    );
    expect(mocks.searchMealMembers).not.toHaveBeenCalled();
  });

  it("requires confirmation before staff posts a meal", async () => {
    await render(["MEAL_READ_BRANCH", "MEAL_SERVE"]);
    const serveTab = [...host.querySelectorAll('[role="tab"]')].find(
      (item) => item.textContent === "Serve",
    );
    await act(async () => (serveTab as HTMLButtonElement).click());
    await settle();
    const memberPicker = host.querySelector(
      'button[aria-label="Member"]',
    ) as HTMLButtonElement;
    await act(async () => memberPicker.click());
    const memberOption = [...host.querySelectorAll(".picker-option")].find(
      (item) => item.textContent?.includes("Riya"),
    ) as HTMLButtonElement;
    await act(async () => memberOption.click());
    await settle();
    expect(host.textContent).toContain("1 of 1 remaining today");
    const action = [...host.querySelectorAll("button")].find(
      (item) => item.textContent === "Confirm serving",
    );
    await act(async () => action?.click());
    expect(mocks.serveMeal).not.toHaveBeenCalled();
    const dialog = host.querySelector('[role="dialog"]');
    const confirm = [...(dialog?.querySelectorAll("button") ?? [])].find(
      (item) => item.textContent === "Confirm serving",
    );
    await act(async () => confirm?.click());
    await settle();
    expect(mocks.serveMeal).toHaveBeenCalledWith(
      "branch-1",
      "member-1",
      "slot-1",
    );
  });
});

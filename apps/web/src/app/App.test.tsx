// @vitest-environment jsdom
import { act } from "react";
import { createRoot, type Root } from "react-dom/client";
import { MemoryRouter } from "react-router-dom";
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import { App } from "./App";
import { getContext, setContext } from "../lib/session";
import type { Invite, TenantContext, User } from "../types/domain";

const mocks = vi.hoisted(() => ({
  getCurrentUser: vi.fn(),
  getMemberContexts: vi.fn(),
  resolveInvite: vi.fn(),
  fastJoinFromInvite: vi.fn(),
}));

vi.mock("../modules/auth/auth.api", () => ({
  getCurrentUser: mocks.getCurrentUser,
  signOut: vi.fn(),
}));
vi.mock("../modules/branches/branches.api", () => ({
  getMemberContexts: mocks.getMemberContexts,
  contextFromInvite: (invite: Invite) => ({
    organizationId: invite.organization.id,
    organizationName: invite.organization.name,
    branchId: invite.branch.id,
    branchName: invite.branch.name,
    timezone: invite.branch.timezone,
  }),
}));
vi.mock("../modules/invites/invites.api", () => ({
  resolveInvite: mocks.resolveInvite,
  fastJoinFromInvite: mocks.fastJoinFromInvite,
  submitJoinRequest: vi.fn(),
}));
vi.mock("../modules/auth/AuthPage", () => ({
  AuthPage: ({
    onAuthenticated,
  }: {
    onAuthenticated: (user: User) => void;
  }) => (
    <button onClick={() => onAuthenticated(user)}>
      Complete Google sign-in
    </button>
  ),
}));
vi.mock("../modules/attendance/MemberAttendancePage", () => ({
  MemberAttendancePage: () => <p>Attendance home loaded</p>,
}));
vi.mock("../modules/attendance/QrAttendancePage", () => ({
  QrAttendancePage: () => <p>QR attendance loaded</p>,
}));
vi.mock("../modules/subscriptions/PurchasePage", () => ({
  PurchasePage: () => <p>Plan purchase loaded</p>,
}));
vi.mock("../modules/payments/MemberFeesPage", () => ({
  MemberFeesPage: () => <p>Fees home loaded</p>,
}));

const user: User = {
  id: "user-1",
  name: "Member",
  email: "member@example.com",
  status: "ACTIVE",
};
const context: TenantContext = {
  organizationId: "org-1",
  organizationName: "Gym",
  branchId: "branch-1",
  branchName: "Main",
  timezone: "Asia/Kolkata",
};
const token = "opaque-token-1234567890";
const invite: Invite = {
  id: "invite-1",
  purpose: "PLAN_PURCHASE",
  organization: { id: "org-1", name: "Gym" },
  branch: { id: "branch-1", name: "Main", timezone: "Asia/Kolkata" },
  joinability: "ALREADY_MEMBER",
};

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
  localStorage.clear();
  window.history.replaceState({}, "", "/home/attendance");
  vi.clearAllMocks();
  mocks.getCurrentUser.mockResolvedValue(user);
  mocks.getMemberContexts.mockResolvedValue([context]);
  mocks.resolveInvite.mockResolvedValue(invite);
  host = document.createElement("div");
  document.body.appendChild(host);
  root = createRoot(host);
});

afterEach(async () => {
  await act(async () => root.unmount());
  host.remove();
});

async function renderApp() {
  await act(async () => {
    root.render(
      <MemoryRouter
        initialEntries={["/home/attendance"]}
        future={{ v7_startTransition: true, v7_relativeSplatPath: true }}
      >
        <App />
      </MemoryRouter>,
    );
  });
  await settle();
}

describe("web member authentication and QR routing", () => {
  it("restores a signed-in member's active branch instead of showing an empty home", async () => {
    await renderApp();
    expect(host.textContent).toContain("Attendance home loaded");
    expect(getContext()).toEqual(context);
  });

  it("discards a stale stored branch that the server no longer returns", async () => {
    setContext({ ...context, branchId: "stale-branch" });
    await renderApp();
    expect(getContext()).toEqual(context);
    expect(host.textContent).toContain("Attendance home loaded");
  });

  it("continues a plan QR after Google sign-in", async () => {
    mocks.getCurrentUser.mockResolvedValue(null);
    window.history.replaceState({}, "", `/invite#token=${token}`);
    await renderApp();
    const button = host.querySelector("button");
    expect(button?.textContent).toContain("Complete Google sign-in");
    await act(async () => button?.click());
    await settle();
    expect(mocks.resolveInvite).toHaveBeenCalledWith(token);
    expect(host.textContent).toContain("Plan purchase loaded");
    expect(mocks.getMemberContexts).not.toHaveBeenCalled();
  });

  it("auto-joins an eligible member before opening the scanned plan", async () => {
    mocks.resolveInvite
      .mockResolvedValueOnce({ ...invite, joinability: "JOINABLE" })
      .mockResolvedValueOnce(invite);
    mocks.fastJoinFromInvite.mockResolvedValue({});
    window.history.replaceState({}, "", `/invite#token=${token}`);
    await renderApp();
    expect(mocks.fastJoinFromInvite).toHaveBeenCalledWith(
      token,
      expect.any(String),
    );
    expect(mocks.resolveInvite).toHaveBeenCalledTimes(2);
    expect(host.textContent).toContain("Plan purchase loaded");
  });

  it("leaves the QR flow when the member opens another page from the app menu", async () => {
    window.history.replaceState({}, "", `/invite#token=${token}`);
    await renderApp();
    expect(host.textContent).toContain("Plan purchase loaded");
    await act(async () => {
      host
        .querySelector<HTMLButtonElement>('button[aria-label="Open actions"]')
        ?.click();
    });
    const attendance = [...host.querySelectorAll("button")].find((button) =>
      button.textContent?.includes("Attendance"),
    );
    await act(async () => attendance?.click());
    await settle();
    expect(host.textContent).toContain("Attendance home loaded");
  });

  it("keeps the QR available after a temporary lookup failure", async () => {
    mocks.resolveInvite
      .mockRejectedValueOnce(new Error("Connection unavailable"))
      .mockResolvedValueOnce(invite);
    window.history.replaceState({}, "", `/invite#token=${token}`);
    await renderApp();
    expect(host.textContent).toContain("Connection unavailable");
    expect(sessionStorage.getItem("dailio_web_qr_intent")).toBe(token);
    const retry = [...host.querySelectorAll("button")].find(
      (button) => button.textContent === "Retry QR",
    );
    await act(async () => retry?.click());
    await settle();
    expect(mocks.resolveInvite).toHaveBeenCalledTimes(2);
    expect(host.textContent).toContain("Plan purchase loaded");
    expect(sessionStorage.getItem("dailio_web_qr_intent")).toBeNull();
  });

  it("shows a retryable error when memberships cannot be restored", async () => {
    mocks.getMemberContexts
      .mockRejectedValueOnce(new Error("Memberships offline"))
      .mockResolvedValueOnce([context]);
    await renderApp();
    expect(host.textContent).toContain("Memberships offline");
    expect(host.textContent).toContain("Retry");
    const retry = [...host.querySelectorAll("button")].find(
      (button) => button.textContent === "Retry",
    );
    await act(async () => retry?.click());
    await settle();
    expect(host.textContent).toContain("Attendance home loaded");
  });
});

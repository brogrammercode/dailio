// @vitest-environment jsdom
import { act } from "react";
import { createRoot, type Root } from "react-dom/client";
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import { AuthPage } from "./AuthPage";
import { signInWithGoogle } from "./auth.api";

vi.mock("./auth.api", () => ({ signInWithGoogle: vi.fn() }));

const signIn = vi.mocked(signInWithGoogle);
let host: HTMLDivElement;
let root: Root;
let googleCallback: (response: GoogleCredentialResponse) => void;

beforeEach(() => {
  Object.assign(globalThis, { IS_REACT_ACT_ENVIRONMENT: true });
  vi.stubEnv("VITE_GOOGLE_CLIENT_ID", "web-client-id");
  signIn.mockReset();
  window.google = {
    accounts: {
      id: {
        initialize: ({ callback }) => {
          googleCallback = callback;
        },
        renderButton: (element) => {
          element.appendChild(document.createElement("button"));
        },
        prompt: () => {},
      },
    },
  };
  host = document.createElement("div");
  document.body.appendChild(host);
  root = createRoot(host);
});

afterEach(async () => {
  await act(async () => root.unmount());
  host.remove();
  delete window.google;
  vi.unstubAllEnvs();
});

describe("Google sign-in", () => {
  it("hands the Google credential to the API and completes authentication", async () => {
    const user = {
      id: "user-1",
      name: "Member",
      email: "member@example.com",
      status: "ACTIVE" as const,
    };
    const onAuthenticated = vi.fn();
    signIn.mockResolvedValue(user);
    await act(async () =>
      root.render(<AuthPage onAuthenticated={onAuthenticated} />),
    );
    await act(async () => googleCallback({ credential: "google-id-token" }));
    expect(signIn).toHaveBeenCalledWith("google-id-token");
    expect(onAuthenticated).toHaveBeenCalledWith(user);
  });

  it("shows a recoverable error when the API rejects the credential", async () => {
    signIn.mockRejectedValue(new Error("Sign-in unavailable"));
    await act(async () => root.render(<AuthPage onAuthenticated={vi.fn()} />));
    await act(async () => googleCallback({ credential: "google-id-token" }));
    expect(host.textContent).toContain("Sign-in failed");
    expect(host.textContent).toContain("Sign-in unavailable");
  });
});

import { apiRequest, ensureBrowserSession } from "../../lib/api-client";
import { clearSession, rememberAccessToken } from "../../lib/session";
import type { User } from "../../types/domain";

export async function signInWithGoogle(idToken: string) {
  const body = await apiRequest<{ accessToken: string; user: User }>(
    "/auth/browser/google",
    {
      method: "POST",
      body: JSON.stringify({ idToken }),
      skipAuth: true,
    },
  );
  rememberAccessToken(body.accessToken);
  return body.user;
}

export async function getCurrentUser() {
  if (!(await ensureBrowserSession())) return null;
  const body = await apiRequest<{ user: User }>("/auth/me");
  return body.user;
}

export async function signOut() {
  try {
    await apiRequest("/auth/browser/logout", {
      method: "POST",
      skipAuth: true,
    });
  } finally {
    clearSession();
  }
}

import type { TenantContext, User } from "../types/domain";

const ACCESS_KEY = "dailio_web_access";
const CONTEXT_KEY = "dailio_web_context";
let accessToken: string | null = null;

export function getAccessToken() {
  return accessToken;
}

export function setAccessToken(token: string | null) {
  accessToken = token;
  if (!token) sessionStorage.removeItem(ACCESS_KEY);
}

export function rememberAccessToken(token: string) {
  accessToken = token;
  sessionStorage.setItem(ACCESS_KEY, token);
}

export function restoreAccessToken() {
  accessToken = sessionStorage.getItem(ACCESS_KEY);
  return accessToken;
}

export function getContext(): TenantContext | null {
  const raw = sessionStorage.getItem(CONTEXT_KEY);
  if (!raw) return null;
  try {
    return JSON.parse(raw) as TenantContext;
  } catch {
    return null;
  }
}

export function setContext(context: TenantContext | null) {
  if (!context) sessionStorage.removeItem(CONTEXT_KEY);
  else sessionStorage.setItem(CONTEXT_KEY, JSON.stringify(context));
}

export function clearSession() {
  accessToken = null;
  sessionStorage.removeItem(ACCESS_KEY);
  sessionStorage.removeItem(CONTEXT_KEY);
  sessionStorage.removeItem("dailio_web_qr_intent");
}

export type AuthState = { user: User | null; ready: boolean };

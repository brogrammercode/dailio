import { ApiError } from "./errors";
import {
  getAccessToken,
  getContext,
  rememberAccessToken,
  restoreAccessToken,
  setAccessToken,
} from "./session";

const baseUrl = (
  import.meta.env.VITE_API_BASE_URL ?? "http://localhost:3000/api/v1"
).replace(/\/$/, "");
let refreshPromise: Promise<boolean> | null = null;

type RequestOptions = RequestInit & {
  skipAuth?: boolean;
  skipRefresh?: boolean;
};

async function parseResponse(response: Response) {
  const text = await response.text();
  if (!text) return null;
  try {
    return JSON.parse(text) as Record<string, unknown>;
  } catch {
    return { message: text };
  }
}

async function refreshBrowserSession() {
  if (refreshPromise) return refreshPromise;
  refreshPromise = fetch(`${baseUrl}/auth/browser/refresh`, {
    method: "POST",
    credentials: "include",
  })
    .then(async (response) => {
      if (!response.ok) return false;
      const body = (await parseResponse(response)) as {
        accessToken?: string;
      } | null;
      if (!body?.accessToken) return false;
      rememberAccessToken(body.accessToken);
      return true;
    })
    .catch(() => false)
    .finally(() => {
      refreshPromise = null;
    });
  return refreshPromise;
}

export async function ensureBrowserSession() {
  restoreAccessToken();
  if (getAccessToken()) return true;
  return refreshBrowserSession();
}

export async function apiRequest<T>(
  path: string,
  options: RequestOptions = {},
  retry = true,
): Promise<T> {
  if (!getAccessToken() && !options.skipAuth) await ensureBrowserSession();

  const context = getContext();
  const headers = new Headers(options.headers);
  headers.set("Accept", "application/json");
  if (
    options.body &&
    !headers.has("Content-Type") &&
    !(options.body instanceof FormData)
  )
    headers.set("Content-Type", "application/json");
  const token = getAccessToken();
  if (token && !options.skipAuth)
    headers.set("Authorization", `Bearer ${token}`);
  if (context) {
    headers.set("X-Organization-Id", context.organizationId);
    headers.set("X-Branch-Id", context.branchId);
  }

  const response = await fetch(`${baseUrl}${path}`, {
    ...options,
    headers,
    credentials: "include",
  });
  if (
    response.status === 401 &&
    retry &&
    !options.skipRefresh &&
    !options.skipAuth
  ) {
    setAccessToken(null);
    if (await refreshBrowserSession())
      return apiRequest<T>(path, { ...options, skipRefresh: true }, false);
  }
  const body = await parseResponse(response);
  if (!response.ok) {
    const payload = body as {
      code?: string;
      message?: string;
      fieldErrors?: Record<string, string[]>;
    } | null;
    throw new ApiError(
      payload?.message ?? "Request failed.",
      response.status,
      payload?.code,
      payload?.fieldErrors,
    );
  }
  return body as T;
}

export async function apiUpload<T>(url: string, form: FormData) {
  const response = await fetch(url, { method: "POST", body: form });
  const body = await parseResponse(response);
  if (!response.ok) throw new ApiError("Upload failed.", response.status);
  return body as T;
}

export { baseUrl };

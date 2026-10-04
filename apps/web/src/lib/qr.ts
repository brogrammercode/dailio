export function readInviteToken() {
  const url = new URL(window.location.href);
  const token = url.hash.startsWith("#")
    ? new URLSearchParams(url.hash.slice(1)).get("token")
    : url.searchParams.get("token");
  if (!token || token.length < 20 || token.length > 512) return null;
  const query = new URLSearchParams(url.search);
  query.delete("token");
  const cleanQuery = query.toString();
  window.history.replaceState(
    {},
    document.title,
    `${url.pathname}${cleanQuery ? `?${cleanQuery}` : ""}`,
  );
  return token;
}

export function rememberQrIntent(token: string) {
  sessionStorage.setItem("dailio_web_qr_intent", token);
}

export function hasQrIntent() {
  return Boolean(sessionStorage.getItem("dailio_web_qr_intent"));
}

export function takeQrIntent() {
  const token = sessionStorage.getItem("dailio_web_qr_intent");
  sessionStorage.removeItem("dailio_web_qr_intent");
  return token;
}

export function extractTokenFromQrValue(value: string) {
  try {
    const url = new URL(value);
    const legacy = url.protocol === "dailio:" && url.hostname === "invite";
    const web =
      (url.protocol === "https:" || url.protocol === "http:") &&
      url.pathname === "/invite";
    if (!legacy && !web) return null;
    const token =
      url.searchParams.get("token") ??
      new URLSearchParams(url.hash.slice(1)).get("token");
    return token && token.length >= 20 ? token : null;
  } catch {
    return null;
  }
}

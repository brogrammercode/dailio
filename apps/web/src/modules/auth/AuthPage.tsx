import { useEffect, useRef, useState } from "react";
import { signInWithGoogle } from "./auth.api";
import { StateCard } from "../../components/feedback/StateCard";
import { safeMessage } from "../../lib/errors";
import type { User } from "../../types/domain";

let googleScriptPromise: Promise<void> | null = null;

function loadGoogleIdentityScript() {
  if (window.google) return Promise.resolve();
  if (googleScriptPromise) return googleScriptPromise;

  googleScriptPromise = new Promise<void>((resolve, reject) => {
    const existing = document.querySelector<HTMLScriptElement>(
      "script[data-google-identity]",
    );
    const script = existing ?? document.createElement("script");
    const cleanup = () => {
      script.removeEventListener("load", onLoad);
      script.removeEventListener("error", onError);
    };
    const onLoad = () => {
      cleanup();
      if (window.google) resolve();
      else reject(new Error("Google Identity Services did not initialize."));
    };
    const onError = () => {
      cleanup();
      reject(new Error("Google Identity Services could not be loaded."));
    };

    script.addEventListener("load", onLoad);
    script.addEventListener("error", onError);
    if (!existing) {
      script.src = "https://accounts.google.com/gsi/client";
      script.async = true;
      script.defer = true;
      script.dataset.googleIdentity = "true";
      document.head.appendChild(script);
    }
  }).catch((error) => {
    googleScriptPromise = null;
    throw error;
  });

  return googleScriptPromise;
}

export function AuthPage({
  onAuthenticated,
}: {
  onAuthenticated: (user: User) => void;
}) {
  const buttonRef = useRef<HTMLDivElement>(null);
  const [error, setError] = useState<string | null>(null);
  const [loading, setLoading] = useState(false);
  const [googleLoading, setGoogleLoading] = useState(true);
  const [googleUnavailable, setGoogleUnavailable] = useState(false);
  const clientId = import.meta.env.VITE_GOOGLE_CLIENT_ID;

  useEffect(() => {
    let cancelled = false;
    async function render() {
      if (!clientId || !buttonRef.current) {
        setGoogleLoading(false);
        return;
      }
      try {
        await loadGoogleIdentityScript();
        if (cancelled || !window.google || !buttonRef.current) return;
        buttonRef.current.replaceChildren();
        window.google.accounts.id.initialize({
          client_id: clientId,
          callback: (response) => {
            if (response.credential) void handleCredential(response.credential);
          },
        });
        window.google.accounts.id.renderButton(buttonRef.current, {
          theme: "outline",
          size: "large",
          width: 320,
          text: "continue_with",
        });
        setGoogleUnavailable(false);
      } catch {
        if (!cancelled) setGoogleUnavailable(true);
      } finally {
        if (!cancelled) setGoogleLoading(false);
      }
    }
    void render();
    return () => {
      cancelled = true;
    };
    // handleCredential is stable for this screen instance.
  }, [clientId]);

  async function handleCredential(idToken: string) {
    setLoading(true);
    setError(null);
    try {
      onAuthenticated(await signInWithGoogle(idToken));
    } catch (cause) {
      setError(safeMessage(cause, "Google sign-in failed."));
    } finally {
      setLoading(false);
    }
  }

  return (
    <div className="page flex min-h-screen items-center justify-center bg-brand-dark px-5 py-10">
      <div className="w-full max-w-[420px] rounded-3xl bg-white p-7 shadow-2xl">
        <div className="mb-8">
          <div className="mb-6 inline-flex h-12 w-12 items-center justify-center rounded-2xl bg-brand text-xl font-bold text-white">
            D
          </div>
          <p className="text-xs font-bold uppercase tracking-[.18em] text-brand">
            Dailio
          </p>
          <h1 className="mt-3 text-4xl font-semibold leading-tight">
            Smart attendance is here.
          </h1>
          <p className="mt-4 text-sm leading-6 text-slate-600">
            Use the same member experience from your phone browser. Scan a gym
            QR, sign in once, and continue safely.
          </p>
        </div>
        <div className="space-y-4">
          <div
            ref={buttonRef}
            className="flex min-h-12 justify-center"
            aria-label="Google sign-in"
          />
          <div className="space-y-2">
            {!clientId && (
              <p className="text-center text-sm text-slate-500">
                Google sign-in is not configured for this environment.
              </p>
            )}
            {clientId && googleLoading && (
              <p className="text-center text-sm text-slate-500">
                Loading Google sign-in…
              </p>
            )}
            {googleUnavailable && (
              <div className="space-y-2 text-center">
                <p className="text-sm text-red-600">
                  Google sign-in could not load. Check your connection and
                  refresh this page.
                </p>
                <button
                  className="secondary-button px-4 py-2 text-sm"
                  onClick={() => window.location.reload()}
                >
                  Try again
                </button>
              </div>
            )}
            {loading && (
              <p className="text-sm text-slate-500">Signing you in…</p>
            )}
          </div>
          {error && (
            <StateCard title="Sign-in failed" message={error} tone="error" />
          )}
        </div>
        <p className="mt-7 text-center text-xs leading-5 text-slate-500">
          By continuing, you agree to use Dailio only for your organization’s
          member services.
        </p>
      </div>
    </div>
  );
}

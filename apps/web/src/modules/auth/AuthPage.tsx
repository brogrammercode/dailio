import { useEffect, useRef, useState } from "react";
import { StateCard } from "../../components/feedback/StateCard";
import { Icon } from "../../components/ui/Icon";
import { safeMessage } from "../../lib/errors";
import type { User } from "../../types/domain";
import { signInWithGoogle } from "./auth.api";

let googleScriptPromise: Promise<void> | null = null;

function loadGoogleIdentityScript() {
  if (window.google) return Promise.resolve();
  if (googleScriptPromise) return googleScriptPromise;

  googleScriptPromise = new Promise<void>((resolve, reject) => {
    const existing = document.querySelector<HTMLScriptElement>(
      "script[data-google-identity]",
    );
    const script = existing ?? document.createElement("script");
    const timeout = window.setTimeout(() => {
      cleanup();
      reject(new Error("Google sign-in took too long to load."));
    }, 15000);
    const cleanup = () => {
      window.clearTimeout(timeout);
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
        if (!clientId) setGoogleUnavailable(true);
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
    <div className="auth-page min-h-screen text-white">
      <div className="auth-content mx-auto flex min-h-screen w-full max-w-[520px] flex-col px-6 py-7">
        <div className="rounded-[28px] bg-[#242424] shadow-2xl">
          <img
            alt="Dailio"
            className="h-36 w-full rounded-[28px] object-cover"
            src="/logo.png"
          />
        </div>

        <section className="mt-12">
          <h1 className="max-w-[390px] text-5xl font-semibold uppercase leading-[0.98] tracking-[-0.055em] sm:text-6xl">
            Smart attendance is here
          </h1>
          <p className="mt-8 max-w-[390px] text-xl leading-[1.45] text-white/75 sm:text-2xl">
            Attendance, memberships, schedules, and operations in one clean
            platform.
          </p>
        </section>

        <section className="mt-auto pt-16">
          <div className="google-button-shell">
            <div
              ref={buttonRef}
              aria-label="Continue with Google"
              className="google-button-host"
            />
          </div>
          <div className="mt-8 flex items-start gap-4 text-base leading-6 text-white/75">
            <span
              aria-hidden="true"
              className="mt-0.5 inline-flex h-7 w-7 shrink-0 items-center justify-center rounded-md border border-white/80 text-white"
            >
              <Icon name="check" size={16} />
            </span>
            <p>
              By continuing, you agree to our Privacy Policy and Terms of
              Service.
            </p>
          </div>
          {clientId && googleLoading && (
            <p className="mt-4 text-center text-sm text-white/60">
              Loading Google sign-in…
            </p>
          )}
          {googleUnavailable && (
            <div className="mt-4 space-y-2 text-center">
              <p className="text-sm text-red-200">
                {clientId
                  ? "Google sign-in could not load. Check the connection and refresh."
                  : "Google sign-in is not configured. Set VITE_GOOGLE_CLIENT_ID in the web environment."}
              </p>
              <button
                className="rounded-full border border-white/40 px-5 py-2 text-sm font-semibold text-white"
                onClick={() => window.location.reload()}
                type="button"
              >
                Try again
              </button>
            </div>
          )}
          {loading && (
            <p className="mt-4 text-center text-sm text-white/60">
              Signing you in…
            </p>
          )}
          {error && (
            <div className="mt-4 text-slate-900">
              <StateCard title="Sign-in failed" message={error} tone="error" />
            </div>
          )}
        </section>
      </div>
    </div>
  );
}

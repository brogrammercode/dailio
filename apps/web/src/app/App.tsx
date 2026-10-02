import { useEffect, useState, type ReactNode } from "react";
import { useLocation, useNavigate } from "react-router-dom";
import { AppShell } from "../components/layout/AppShell";
import { LoadingCard, StateCard } from "../components/feedback/StateCard";
import { AuthPage } from "../modules/auth/AuthPage";
import { getCurrentUser, signOut } from "../modules/auth/auth.api";
import {
  fastJoinFromInvite,
  resolveInvite,
  submitJoinRequest,
} from "../modules/invites/invites.api";
import { QrAttendancePage } from "../modules/attendance/QrAttendancePage";
import { MemberAttendancePage } from "../modules/attendance/MemberAttendancePage";
import { PurchasePage } from "../modules/subscriptions/PurchasePage";
import { MemberFeesPage } from "../modules/payments/MemberFeesPage";
import { contextFromInvite } from "../modules/branches/branches.api";
import { safeMessage } from "../lib/errors";
import { newIdempotencyKey } from "../lib/idempotency";
import { getContext, setContext } from "../lib/session";
import { readInviteToken, rememberQrIntent, takeQrIntent } from "../lib/qr";
import type {
  AttendanceSession,
  Invite,
  PaymentRequest,
  User,
} from "../types/domain";

type InviteState = { token: string; invite: Invite } | null;

export function App() {
  const navigate = useNavigate();
  const location = useLocation();
  const [user, setUser] = useState<User | null>(null);
  const [ready, setReady] = useState(false);
  const [inviteState, setInviteState] = useState<InviteState>(null);
  const [inviteLoading, setInviteLoading] = useState(false);
  const [inviteError, setInviteError] = useState<string | null>(null);
  const [result, setResult] = useState<{
    title: string;
    message: string;
    tone: "success" | "pending";
  } | null>(null);

  useEffect(() => {
    const token = readInviteToken();
    if (token) rememberQrIntent(token);
    getCurrentUser()
      .then(setUser)
      .catch(() => setUser(null))
      .finally(() => setReady(true));
  }, []);

  useEffect(() => {
    if (!ready || !user || inviteState || inviteLoading) return;
    const token = takeQrIntent();
    if (!token) return;
    setInviteLoading(true);
    setInviteError(null);
    resolveInvite(token)
      .then(async (invite) => {
        if (
          invite.joinability === "JOINABLE" ||
          invite.joinability === "ALREADY_PENDING"
        ) {
          await fastJoinFromInvite(token, newIdempotencyKey("web-fast-join"));
          return resolveInvite(token);
        }
        return invite;
      })
      .then((invite) => {
        setInviteState({ token, invite });
        setContext(contextFromInvite(invite));
      })
      .catch((cause) =>
        setInviteError(
          safeMessage(cause, "This QR code is invalid or unavailable."),
        ),
      )
      .finally(() => setInviteLoading(false));
  }, [ready, user, inviteState, inviteLoading]);

  async function handleSignOut() {
    await signOut();
    setUser(null);
    setInviteState(null);
    setResult(null);
    navigate("/sign-in");
  }
  function handleAttendanceDone(session: AttendanceSession) {
    setResult({
      title: "Attendance confirmed",
      message: `Dailio recorded your ${session.state === "OPEN" ? "clock-in" : "clock-out"} using server time.`,
      tone: "success",
    });
  }
  function handlePaymentDone(request: PaymentRequest) {
    setResult({
      title: "Payment request submitted",
      message: `Your request is ${request.status.toLowerCase()}. It will remain separate from Paid until an authorized reviewer confirms it.`,
      tone: "pending",
    });
  }

  if (!ready)
    return (
      <div className="page flex items-center justify-center px-5">
        <div className="shell">
          <LoadingCard label="Starting Dailio" />
        </div>
      </div>
    );
  if (!user) return <AuthPage onAuthenticated={setUser} />;
  const context = getContext();
  const authenticatedShell = (
    children: ReactNode,
    active: "attendance" | "fees" = "attendance",
  ) => (
    <AppShell
      user={user}
      context={context}
      active={active}
      onBack={() =>
        window.history.length > 1 ? navigate(-1) : navigate("/home/attendance")
      }
      onNavigate={(route) => navigate(`/home/${route}`)}
      onSignOut={() => void handleSignOut()}
    >
      {children}
    </AppShell>
  );
  if (inviteLoading)
    return authenticatedShell(<LoadingCard label="Checking QR code" />);
  if (inviteError)
    return authenticatedShell(
      <StateCard
        title="QR code unavailable"
        message={inviteError}
        tone="error"
        action={
          <button
            className="primary-button w-full"
            onClick={() => {
              setInviteError(null);
              navigate("/home/attendance");
            }}
            type="button"
          >
            Go to Dailio
          </button>
        }
      />,
    );
  if (result)
    return authenticatedShell(
      <StateCard
        title={result.title}
        message={result.message}
        tone={result.tone}
        action={
          <button
            className="primary-button w-full"
            onClick={() => {
              setResult(null);
              navigate("/home/fees");
            }}
            type="button"
          >
            Open member home
          </button>
        }
      />,
      "fees",
    );

  if (inviteState) {
    const { token, invite } = inviteState;
    if (invite.joinability === "MEMBERSHIP_INACTIVE")
      return authenticatedShell(
        <StateCard
          title="Membership unavailable"
          message="This membership is not active, so Dailio cannot perform branch operations."
          tone="error"
        />,
      );
    if (invite.purpose === "PLAN_PURCHASE")
      return authenticatedShell(
        <PurchasePage
          token={token}
          invite={invite}
          onDone={handlePaymentDone}
        />,
        "fees",
      );
    return authenticatedShell(
      <QrAttendancePage
        token={token}
        invite={invite}
        onDone={handleAttendanceDone}
      />,
    );
  }

  if (!context)
    return authenticatedShell(
      <StateCard
        title="Scan a Dailio QR code"
        message="Use the branch gate QR for attendance or a plan QR to start a subscription request."
      />,
    );
  const active = location.pathname.includes("fees") ? "fees" : "attendance";
  const content =
    active === "fees" ? (
      <MemberFeesPage
        onBuy={() =>
          setResult({
            title: "Scan a plan QR",
            message:
              "The branch plan QR opens the correct plan and keeps its server-resolved price and terms intact.",
            tone: "pending",
          })
        }
      />
    ) : (
      <MemberAttendancePage />
    );
  return authenticatedShell(content, active);
}

export function JoinRequestPage({
  invite,
  token,
  onSubmitted,
}: {
  invite: Invite;
  token: string;
  onSubmitted: () => void;
}) {
  const [message, setMessage] = useState("");
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  async function submit() {
    setBusy(true);
    setError(null);
    try {
      await submitJoinRequest(
        token,
        newIdempotencyKey("web-join"),
        message.trim() || undefined,
      );
      onSubmitted();
    } catch (cause) {
      setError(safeMessage(cause, "Join request could not be submitted."));
    } finally {
      setBusy(false);
    }
  }
  return (
    <div className="page flex min-h-screen items-center justify-center px-5">
      <div className="shell space-y-5">
        <div>
          <p className="section-title">Join branch</p>
          <h1 className="mt-2 text-3xl font-semibold">{invite.branch.name}</h1>
          <p className="mt-2 text-sm text-slate-600">
            {invite.organization.name}
          </p>
        </div>
        <section className="card space-y-4 p-5">
          <p className="text-sm leading-6 text-slate-600">
            Your request will be reviewed by an authorized owner or staff
            member. You will not be counted as an active member until approval.
          </p>
          <label className="block text-sm font-semibold">
            Message{" "}
            <textarea
              className="field mt-2 min-h-28"
              value={message}
              maxLength={1000}
              onChange={(event) => setMessage(event.target.value)}
              placeholder="Optional message to the branch"
            />
          </label>
          {error && (
            <StateCard title="Could not submit" message={error} tone="error" />
          )}
          <button
            className="primary-button w-full"
            disabled={busy}
            onClick={() => void submit()}
          >
            {busy ? "Submitting…" : "Request to join"}
          </button>
        </section>
      </div>
    </div>
  );
}

import { useState, type ReactNode } from "react";
import type { TenantContext, User } from "../../types/domain";

function Icon({
  name,
  size = 22,
}: {
  name: "arrow-left" | "bell" | "more" | "calendar" | "fees" | "logout";
  size?: number;
}) {
  const paths = {
    "arrow-left": (
      <>
        <path d="M19 12H5" />
        <path d="m12 19-7-7 7-7" />
      </>
    ),
    bell: (
      <>
        <path d="M18 8a6 6 0 0 0-12 0c0 7-3 7-3 9h18c0-2-3-2-3-9" />
        <path d="M10 21h4" />
      </>
    ),
    more: (
      <>
        <circle cx="5" cy="12" r="1" fill="currentColor" stroke="none" />
        <circle cx="12" cy="12" r="1" fill="currentColor" stroke="none" />
        <circle cx="19" cy="12" r="1" fill="currentColor" stroke="none" />
      </>
    ),
    calendar: (
      <>
        <rect x="4" y="5" width="16" height="15" rx="2" />
        <path d="M8 3v4M16 3v4M4 10h16" />
      </>
    ),
    fees: (
      <>
        <rect x="4" y="5" width="16" height="14" rx="2" />
        <path d="M8 9h8M8 13h5" />
      </>
    ),
    logout: (
      <>
        <path d="M10 17l5-5-5-5" />
        <path d="M15 12H3" />
        <path d="M21 19V5a2 2 0 0 0-2-2h-6" />
      </>
    ),
  };

  return (
    <svg
      aria-hidden="true"
      fill="none"
      height={size}
      viewBox="0 0 24 24"
      width={size}
      xmlns="http://www.w3.org/2000/svg"
    >
      <g
        stroke="currentColor"
        strokeLinecap="round"
        strokeLinejoin="round"
        strokeWidth="1.8"
      >
        {paths[name]}
      </g>
    </svg>
  );
}

export function AppShell({
  user,
  context,
  active,
  onNavigate,
  onSignOut,
  onBack,
  children,
}: {
  user: User;
  context: TenantContext | null;
  active: "attendance" | "fees";
  onNavigate: (route: "attendance" | "fees") => void;
  onSignOut: () => void;
  onBack?: () => void;
  children: ReactNode;
}) {
  const [menuOpen, setMenuOpen] = useState(false);
  const [confirmSignOut, setConfirmSignOut] = useState(false);

  function requestSignOut() {
    setMenuOpen(false);
    setConfirmSignOut(true);
  }

  return (
    <div className="page">
      <div className="shell pb-8">
        <header className="app-bar">
          <button
            aria-label="Go back"
            className="icon-button"
            onClick={onBack}
            type="button"
          >
            <Icon name="arrow-left" />
          </button>
          <div className="min-w-0 flex-1 px-3">
            <p className="truncate text-xl font-semibold tracking-[-0.03em]">
              Dailio
            </p>
            {context?.branchName && (
              <p className="truncate text-[11px] text-slate-500">
                {context.branchName}
              </p>
            )}
          </div>
          <button
            aria-label="Notifications"
            className="icon-button"
            type="button"
          >
            <Icon name="bell" size={21} />
          </button>
          <div className="relative">
            <button
              aria-expanded={menuOpen}
              aria-label="Open actions"
              className="icon-button"
              onClick={() => setMenuOpen((open) => !open)}
              type="button"
            >
              <Icon name="more" size={24} />
            </button>
            {menuOpen && (
              <div className="app-menu" role="menu">
                <div className="border-b border-line px-4 py-3">
                  <p className="truncate text-sm font-semibold">{user.name}</p>
                  <p className="truncate text-xs text-slate-500">
                    {user.email}
                  </p>
                </div>
                <button
                  className={`app-menu-item ${active === "attendance" ? "text-brand" : ""}`}
                  onClick={() => {
                    setMenuOpen(false);
                    onNavigate("attendance");
                  }}
                  role="menuitem"
                  type="button"
                >
                  <Icon name="calendar" size={18} /> Attendance
                </button>
                <button
                  className={`app-menu-item ${active === "fees" ? "text-brand" : ""}`}
                  onClick={() => {
                    setMenuOpen(false);
                    onNavigate("fees");
                  }}
                  role="menuitem"
                  type="button"
                >
                  <Icon name="fees" size={18} /> Fees
                </button>
                <button
                  className="app-menu-item border-t border-line text-red-600"
                  onClick={requestSignOut}
                  role="menuitem"
                  type="button"
                >
                  <Icon name="logout" size={18} /> Sign out
                </button>
              </div>
            )}
          </div>
        </header>
        <main className="px-5 py-3">{children}</main>
      </div>
      {confirmSignOut && (
        <div className="confirm-backdrop" role="presentation">
          <section
            aria-labelledby="sign-out-title"
            aria-modal="true"
            className="confirm-dialog"
            role="dialog"
          >
            <p className="section-title">Account</p>
            <h2 className="mt-2 text-xl font-semibold" id="sign-out-title">
              Sign out of Dailio?
            </h2>
            <p className="mt-2 text-sm leading-6 text-slate-600">
              You can sign in again with Google whenever you need to use this
              member experience.
            </p>
            <div className="mt-5 grid grid-cols-2 gap-3">
              <button
                className="secondary-button"
                onClick={() => setConfirmSignOut(false)}
                type="button"
              >
                Cancel
              </button>
              <button
                className="danger-button"
                onClick={onSignOut}
                type="button"
              >
                Sign out
              </button>
            </div>
          </section>
        </div>
      )}
    </div>
  );
}

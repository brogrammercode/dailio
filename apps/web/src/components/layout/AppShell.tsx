import { useState, type ReactNode } from "react";
import { Icon } from "../ui/Icon";
import type { TenantContext, User } from "../../types/domain";

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
  active: "attendance" | "fees" | "meals";
  onNavigate: (route: "attendance" | "fees" | "meals") => void;
  onSignOut: () => void;
  onBack?: () => void;
  children: ReactNode;
}) {
  const [menuOpen, setMenuOpen] = useState(false);
  const [notificationOpen, setNotificationOpen] = useState(false);
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
            onClick={onBack ?? (() => window.history.back())}
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
            aria-expanded={notificationOpen}
            className="icon-button"
            onClick={() => {
              setMenuOpen(false);
              setNotificationOpen((open) => !open);
            }}
            type="button"
          >
            <Icon name="bell" size={21} />
          </button>
          {notificationOpen && (
            <div className="app-menu right-16 top-12 w-52" role="status">
              <p className="px-4 py-4 text-sm text-slate-600">
                No new notifications.
              </p>
            </div>
          )}
          <div className="relative">
            <button
              aria-expanded={menuOpen}
              aria-label="Open actions"
              className="icon-button"
              onClick={() => {
                setNotificationOpen(false);
                setMenuOpen((open) => !open);
              }}
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
                {context?.organizationType === "FOOD_SERVICE" &&
                  (context?.permissions?.includes("ALL") ||
                    context?.permissions?.some((permission) =>
                      [
                        "MEAL_READ_SELF",
                        "MEAL_READ_BRANCH",
                        "MEAL_SERVE",
                        "MEAL_MANAGE",
                      ].includes(permission),
                    )) && (
                    <button
                      className={`app-menu-item ${active === "meals" ? "text-brand" : ""}`}
                      onClick={() => {
                        setMenuOpen(false);
                        onNavigate("meals");
                      }}
                      role="menuitem"
                      type="button"
                    >
                      <Icon name="meals" size={18} /> Meals
                    </button>
                  )}
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

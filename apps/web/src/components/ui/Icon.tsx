import type { ReactNode } from "react";

type IconName =
  | "arrow-left"
  | "bell"
  | "more"
  | "calendar"
  | "fees"
  | "meals"
  | "logout"
  | "log-in"
  | "log-out"
  | "clock"
  | "location"
  | "camera"
  | "geofence"
  | "qr"
  | "check"
  | "chevron-down";

const paths: Record<IconName, ReactNode> = {
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
  meals: (
    <>
      <path d="M4 13h16M6 13a6 6 0 0 1 12 0M4 13a8 8 0 0 0 16 0M12 5v2" />
    </>
  ),
  logout: (
    <>
      <path d="M10 17l5-5-5-5" />
      <path d="M15 12H3" />
      <path d="M21 19V5a2 2 0 0 0-2-2h-6" />
    </>
  ),
  "log-in": (
    <>
      <path d="M13 17l5-5-5-5" />
      <path d="M18 12H4" />
      <path d="M4 19V5a2 2 0 0 1 2-2h5" />
    </>
  ),
  "log-out": (
    <>
      <path d="M11 17l-5-5 5-5" />
      <path d="M6 12h14" />
      <path d="M20 19V5a2 2 0 0 0-2-2h-5" />
    </>
  ),
  clock: (
    <>
      <circle cx="12" cy="12" r="8.5" />
      <path d="M12 7v5l3 2" />
    </>
  ),
  location: (
    <>
      <path d="M19 10c0 5-7 10-7 10S5 15 5 10a7 7 0 1 1 14 0Z" />
      <circle cx="12" cy="10" r="2.5" />
    </>
  ),
  camera: (
    <>
      <path d="M4 8h3l1.5-2h7L17 8h3v10H4V8Z" />
      <circle cx="12" cy="13" r="3" />
    </>
  ),
  geofence: (
    <>
      <circle cx="12" cy="12" r="7.5" />
      <circle cx="12" cy="12" r="2.5" />
      <path d="M12 2v3M12 19v3M2 12h3M19 12h3" />
    </>
  ),
  qr: (
    <>
      <path d="M4 4h6v6H4zM14 4h6v6h-6zM4 14h6v6H4z" />
      <path d="M14 14h2v2h-2zM18 14h2v2h-2zM14 18h2v2h-2zM18 18h2v2h-2z" />
    </>
  ),
  check: <path d="m5 12 4 4L19 6" />,
  "chevron-down": <path d="m6 9 6 6 6-6" />,
};

export function Icon({ name, size = 22 }: { name: IconName; size?: number }) {
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

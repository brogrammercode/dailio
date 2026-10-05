export function formatMinorInput(minor: number): string {
  const whole = Math.floor(minor / 100);
  return `${whole}.${String(minor % 100).padStart(2, "0")}`;
}

export function parseMinorInput(value: string): number | null {
  const trimmed = value.trim();
  if (!/^\d+(\.\d{1,2})?$/.test(trimmed)) return null;
  const [whole, fraction = ""] = trimmed.split(".");
  const amount = Number(whole) * 100 + Number(fraction.padEnd(2, "0"));
  return Number.isSafeInteger(amount) && amount > 0 && amount <= 2_147_483_647
    ? amount
    : null;
}

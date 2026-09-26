/**
 * Validate a timezone using the runtime's IANA timezone database. This keeps
 * attendance date boundaries and shift calculations from receiving a value
 * that would make Intl.DateTimeFormat throw at request time.
 */
export function isValidIanaTimezone(value: string) {
  try {
    new Intl.DateTimeFormat('en-US', { timeZone: value }).format();
    return true;
  } catch {
    return false;
  }
}

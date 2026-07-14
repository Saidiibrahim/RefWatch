export function parseISODate(value: string | undefined): Date | undefined {
  if (!value) return undefined;
  const date = new Date(value);
  if (Number.isNaN(date.valueOf())) throw new Error("invalid_iso_date");
  return date;
}

export function toISOString(value: Date | string): string {
  return value instanceof Date ? value.toISOString() : new Date(value).toISOString();
}

export function now(): Date {
  return new Date();
}

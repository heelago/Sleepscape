export function loadFloat(key: string, defaultValue: number): number {
  const v = localStorage.getItem(key);
  if (v === null) return defaultValue;
  const parsed = parseFloat(v);
  return isNaN(parsed) ? defaultValue : parsed;
}

export function saveFloat(key: string, value: number): void {
  localStorage.setItem(key, String(value));
}

export function loadBool(key: string, defaultValue: boolean): boolean {
  const v = localStorage.getItem(key);
  if (v === null) return defaultValue;
  return v === 'true';
}

export function saveBool(key: string, value: boolean): void {
  localStorage.setItem(key, String(value));
}

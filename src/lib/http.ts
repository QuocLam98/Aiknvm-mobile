import { requireBaseUrl } from '../config/env';
import { AuthRepository } from '../repositories/authRepository';

export async function http<T>(path: string, init?: RequestInit): Promise<T> {
  const base = requireBaseUrl();
  const url = base + (path.startsWith('/') ? path : `/${path}`);
  const token = await AuthRepository.getToken();
  const res = await fetch(url, {
    ...init,
    headers: {
      'Content-Type': 'application/json',
      ...(token ? { Authorization: `Bearer ${token}` } : {}),
      ...(init?.headers || {}),
    },
  });
  if (!res.ok) {
    const text = await res.text();
    throw new Error(`HTTP ${res.status}: ${text}`);
  }
  if (res.status === 204) return undefined as unknown as T;
  return (await res.json()) as T;
}

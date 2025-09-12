import { requireBaseUrl, env } from '../config/env';
import { getToken } from './tokenStore';

type HttpOptions = RequestInit & { timeoutMs?: number };

export async function http<T>(path: string, init?: HttpOptions): Promise<T> {
  const started = Date.now();
  const base = requireBaseUrl();
  if (!base) {
    throw new Error('NO_BASE_URL');
  }
  const url = base + (path.startsWith('/') ? path : `/${path}`);
  const token = await getToken();

  const controller = new AbortController();
  const timeoutMs = init?.timeoutMs ?? 10000;
  const timeout = setTimeout(() => controller.abort(), timeoutMs);
  if (env.DEBUG_HTTP) {
    console.log(`[http] → ${init?.method || 'GET'} ${url}`);
  }
  try {
    const res = await fetch(url, {
      ...init,
      signal: controller.signal,
      headers: {
        'Content-Type': 'application/json',
        ...(token ? { Authorization: `Bearer ${token}` } : {}),
        ...(init?.headers || {}),
      },
    });
    if (env.DEBUG_HTTP) {
      console.log(`[http] ← ${res.status} ${url} (${Date.now() - started}ms)`);
    }
    if (!res.ok) {
      const text = await res.text();
      const err = new Error(`HTTP ${res.status}: ${text}`);
      if (env.DEBUG_HTTP) console.warn('[http] error', err);
      throw err;
    }
    if (res.status === 204) return undefined as unknown as T;
    return (await res.json()) as T;
  } catch (e: any) {
    if (e?.name === 'AbortError') {
      const err = new Error(`TIMEOUT after ${timeoutMs}ms for ${url}`);
      if (env.DEBUG_HTTP) console.warn('[http] timeout', err.message);
      throw err;
    }
    throw e;
  } finally {
    clearTimeout(timeout);
  }
}

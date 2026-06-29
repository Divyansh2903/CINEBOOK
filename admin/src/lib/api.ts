const BASE = (import.meta.env.VITE_API_URL as string | undefined) ?? "http://localhost:4000";
const KEY = "cinebook.tokens";

export interface Tokens {
  accessToken: string;
  refreshToken: string;
}

export const getTokens = (): Tokens | null => {
  const raw = localStorage.getItem(KEY);
  return raw ? (JSON.parse(raw) as Tokens) : null;
};
export const setTokens = (tokens: Tokens | null): void => {
  if (tokens) localStorage.setItem(KEY, JSON.stringify(tokens));
  else localStorage.removeItem(KEY);
};

export class ApiError extends Error {
  status: number;
  details: unknown;
  constructor(status: number, message: string, details?: unknown) {
    super(message);
    this.status = status;
    this.details = details;
  }
}

async function request(path: string, options: RequestInit, token?: string): Promise<Response> {
  const headers = new Headers(options.headers);
  if (options.body) headers.set("content-type", "application/json");
  if (token) headers.set("authorization", `Bearer ${token}`);
  return fetch(`${BASE}${path}`, { ...options, headers });
}

async function refreshTokens(): Promise<Tokens | null> {
  const current = getTokens();
  if (!current) return null;
  const res = await request("/auth/refresh", {
    method: "POST",
    body: JSON.stringify({ refreshToken: current.refreshToken }),
  });
  if (!res.ok) {
    setTokens(null);
    return null;
  }
  const data = (await res.json()) as Tokens;
  const next = { accessToken: data.accessToken, refreshToken: data.refreshToken };
  setTokens(next);
  return next;
}

export async function api<T = unknown>(path: string, options: RequestInit = {}): Promise<T> {
  let tokens = getTokens();
  let res = await request(path, options, tokens?.accessToken);

  if (res.status === 401 && tokens) {
    tokens = await refreshTokens();
    if (tokens) res = await request(path, options, tokens.accessToken);
  }

  const text = await res.text();
  const data = text ? JSON.parse(text) : null;
  if (!res.ok) throw new ApiError(res.status, data?.message ?? res.statusText, data?.details);
  return data as T;
}

export const apiGet = <T>(path: string) => api<T>(path);
export const apiPost = <T>(path: string, body?: unknown) =>
  api<T>(path, { method: "POST", body: body !== undefined ? JSON.stringify(body) : undefined });
export const apiPatch = <T>(path: string, body?: unknown) =>
  api<T>(path, { method: "PATCH", body: JSON.stringify(body) });
export const apiDelete = <T>(path: string) => api<T>(path, { method: "DELETE" });

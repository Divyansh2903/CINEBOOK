import { createContext, useContext, useEffect, useState, type ReactNode } from "react";
import { api, apiPost, getTokens, setTokens } from "./api";

export type Role = "CUSTOMER" | "HALL_MANAGER" | "ADMIN";

export interface User {
  id: string;
  name: string;
  phone: string;
  role: Role;
}

interface AuthContextValue {
  user: User | null;
  loading: boolean;
  requestOtp: (phone: string) => Promise<{ sent: boolean; devCode?: string }>;
  login: (phone: string, code: string) => Promise<User>;
  logout: () => void;
}

const AuthContext = createContext<AuthContextValue | null>(null);

export function useAuth(): AuthContextValue {
  const ctx = useContext(AuthContext);
  if (!ctx) throw new Error("useAuth must be used within AuthProvider");
  return ctx;
}

export function AuthProvider({ children }: { children: ReactNode }) {
  const [user, setUser] = useState<User | null>(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    (async () => {
      if (getTokens()) {
        try {
          const { user } = await api<{ user: User }>("/auth/me");
          setUser(user);
        } catch {
          setTokens(null);
        }
      }
      setLoading(false);
    })();
  }, []);

  const requestOtp = (phone: string) =>
    apiPost<{ sent: boolean; devCode?: string }>("/auth/request-otp", { phone });

  const login = async (phone: string, code: string) => {
    const res = await apiPost<{ accessToken: string; refreshToken: string; user: User }>(
      "/auth/verify-otp",
      { phone, code },
    );
    setTokens({ accessToken: res.accessToken, refreshToken: res.refreshToken });
    setUser(res.user);
    return res.user;
  };

  const logout = () => {
    const tokens = getTokens();
    if (tokens) apiPost("/auth/logout", { refreshToken: tokens.refreshToken }).catch(() => {});
    setTokens(null);
    setUser(null);
  };

  return (
    <AuthContext.Provider value={{ user, loading, requestOtp, login, logout }}>
      {children}
    </AuthContext.Provider>
  );
}

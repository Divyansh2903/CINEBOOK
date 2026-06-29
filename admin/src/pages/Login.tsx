import { useState, type FormEvent } from "react";
import { useAuth } from "../lib/auth";
import { ApiError } from "../lib/api";
import { Button, Field, Icon, Input } from "../components/ui";

export default function Login() {
  const { requestOtp, login } = useAuth();
  const [phone, setPhone] = useState("+91");
  const [code, setCode] = useState("");
  const [step, setStep] = useState<"phone" | "code">("phone");
  const [devCode, setDevCode] = useState<string | undefined>();
  const [error, setError] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);

  const send = async (e: FormEvent) => {
    e.preventDefault();
    setError(null);
    setBusy(true);
    try {
      const res = await requestOtp(phone);
      setDevCode(res.devCode);
      setStep("code");
    } catch (err) {
      setError(err instanceof ApiError ? err.message : "Couldn't send the code");
    } finally {
      setBusy(false);
    }
  };

  const verify = async (e: FormEvent) => {
    e.preventDefault();
    setError(null);
    setBusy(true);
    try {
      const user = await login(phone, code);
      if (user.role === "CUSTOMER") setError("This account can't access the dashboard.");
    } catch (err) {
      setError(err instanceof ApiError ? err.message : "Invalid or expired code");
    } finally {
      setBusy(false);
    }
  };

  return (
    <div className="flex min-h-screen items-center justify-center p-6">
      <div className="glass w-full max-w-md rounded-2xl p-8">
        <div className="mb-7 text-center">
          <span className="font-display text-4xl font-bold tracking-tight text-primary">CineBook</span>
          <p className="mt-1 text-sm text-muted">Management Console</p>
        </div>

        {step === "phone" ? (
          <form onSubmit={send} className="space-y-4">
            <Field label="Phone number">
              <Input value={phone} onChange={(e) => setPhone(e.target.value)} placeholder="+9190…" autoFocus />
            </Field>
            <Button className="w-full" disabled={busy}>
              {busy ? "Sending…" : "Send code"}
            </Button>
          </form>
        ) : (
          <form onSubmit={verify} className="space-y-4">
            <Field label="Verification code">
              <Input
                value={code}
                onChange={(e) => setCode(e.target.value)}
                placeholder="6-digit code"
                inputMode="numeric"
                maxLength={6}
                autoFocus
              />
            </Field>
            {devCode && (
              <p className="rounded-lg bg-primary/10 px-3 py-2 text-xs text-primary">
                Simulated SMS — your code is <b>{devCode}</b>
              </p>
            )}
            <Button className="w-full" disabled={busy}>
              {busy ? "Verifying…" : "Sign in"}
            </Button>
            <button
              type="button"
              className="w-full text-center text-xs text-muted hover:text-primary"
              onClick={() => {
                setStep("phone");
                setError(null);
              }}
            >
              Use a different number
            </button>
          </form>
        )}

        {error && (
          <p className="mt-4 flex items-center gap-2 text-sm text-danger">
            <Icon name="error" className="text-base" />
            {error}
          </p>
        )}
        <p className="mt-6 text-center text-xs text-muted">
          Demo — admin <b>+919000000001</b> · manager <b>+919000000002</b>
        </p>
      </div>
    </div>
  );
}

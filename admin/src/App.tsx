import { Navigate, Route, Routes } from "react-router-dom";
import { useAuth } from "./lib/auth";
import { Layout } from "./components/Layout";
import { Button, Icon } from "./components/ui";
import Login from "./pages/Login";
import Dashboard from "./pages/Dashboard";
import Users from "./pages/Users";
import Movies from "./pages/Movies";
import Theatres from "./pages/Theatres";
import Shows from "./pages/Shows";
import Reports from "./pages/Reports";
import Activity from "./pages/Activity";

function Centered({ children }: { children: React.ReactNode }) {
  return <div className="flex h-screen items-center justify-center p-6">{children}</div>;
}

function NoAccess() {
  const { logout } = useAuth();
  return (
    <Centered>
      <div className="glass max-w-sm rounded-xl p-8 text-center">
        <Icon name="lock" className="text-4xl text-danger" />
        <h1 className="mt-3 text-xl font-bold">No dashboard access</h1>
        <p className="mt-1 text-sm text-muted">This dashboard is for hall managers and admins. Use the CineBook app to book tickets.</p>
        <Button variant="secondary" className="mt-5" onClick={logout}>
          Sign out
        </Button>
      </div>
    </Centered>
  );
}

export default function App() {
  const { user, loading } = useAuth();

  if (loading) {
    return (
      <Centered>
        <Icon name="progress_activity" className="animate-spin text-4xl text-primary" />
      </Centered>
    );
  }

  if (!user) {
    return (
      <Routes>
        <Route path="*" element={<Login />} />
      </Routes>
    );
  }

  if (user.role === "CUSTOMER") return <NoAccess />;

  const isAdmin = user.role === "ADMIN";

  return (
    <Routes>
      <Route element={<Layout />}>
        <Route path="/" element={<Dashboard />} />
        <Route path="/shows" element={<Shows />} />
        {isAdmin && [
          <Route key="users" path="/users" element={<Users />} />,
          <Route key="movies" path="/movies" element={<Movies />} />,
          <Route key="theatres" path="/theatres" element={<Theatres />} />,
          <Route key="reports" path="/reports" element={<Reports />} />,
          <Route key="activity" path="/activity" element={<Activity />} />,
        ]}
        <Route path="*" element={<Navigate to="/" replace />} />
      </Route>
    </Routes>
  );
}

import { NavLink, Outlet } from "react-router-dom";
import { useAuth, type Role } from "../lib/auth";
import { Button, Icon } from "./ui";

const NAV: { to: string; label: string; icon: string; roles: Role[] }[] = [
  { to: "/", label: "Dashboard", icon: "dashboard", roles: ["ADMIN", "HALL_MANAGER"] },
  { to: "/users", label: "Users", icon: "group", roles: ["ADMIN"] },
  { to: "/movies", label: "Movies", icon: "movie", roles: ["ADMIN"] },
  { to: "/theatres", label: "Theatres", icon: "theaters", roles: ["ADMIN"] },
  { to: "/shows", label: "Shows", icon: "event_seat", roles: ["ADMIN", "HALL_MANAGER"] },
  { to: "/reports", label: "Reports", icon: "bar_chart", roles: ["ADMIN"] },
  { to: "/activity", label: "Activity Log", icon: "history", roles: ["ADMIN"] },
];

const roleLabel: Record<Role, string> = {
  ADMIN: "System Administrator",
  HALL_MANAGER: "Hall Manager",
  CUSTOMER: "Customer",
};

export function Layout() {
  const { user, logout } = useAuth();
  const items = NAV.filter((n) => user && n.roles.includes(user.role));

  return (
    <div className="flex h-screen overflow-hidden">
      <aside className="hidden w-64 shrink-0 flex-col border-r border-outline/15 bg-surface md:flex">
        <div className="flex h-20 items-center border-b border-outline/10 px-6">
          <span className="font-display text-3xl font-bold tracking-tight text-primary">CineBook</span>
        </div>
        <nav className="flex-1 space-y-1.5 overflow-y-auto p-3">
          {items.map((item) => (
            <NavLink
              key={item.to}
              to={item.to}
              end={item.to === "/"}
              className={({ isActive }) =>
                `group flex items-center gap-3 rounded-lg px-3 py-2.5 text-sm font-semibold transition ${
                  isActive
                    ? "gold-glow bg-surface-container text-primary"
                    : "text-muted hover:bg-surface-low hover:text-primary"
                }`
              }
            >
              {({ isActive }) => (
                <>
                  <Icon name={item.icon} filled={isActive} className="text-xl transition group-hover:scale-110" />
                  {item.label}
                </>
              )}
            </NavLink>
          ))}
        </nav>
        <div className="border-t border-outline/10 p-4">
          <div className="flex items-center gap-3">
            <div className="flex h-10 w-10 shrink-0 items-center justify-center rounded-full bg-surface-high text-primary">
              <Icon name="person" filled />
            </div>
            <div className="min-w-0 flex-1">
              <p className="truncate text-sm font-semibold text-fg">{user?.name}</p>
              <p className="truncate text-xs text-primary">{user && roleLabel[user.role]}</p>
            </div>
          </div>
        </div>
      </aside>

      <main className="flex flex-1 flex-col overflow-hidden">
        <header className="flex h-20 shrink-0 items-center justify-between border-b border-line/50 px-8">
          <span className="font-display text-2xl font-bold tracking-tight text-primary md:hidden">CineBook</span>
          <div className="hidden md:block" />
          <Button variant="ghost" onClick={logout}>
            <Icon name="logout" className="text-lg" /> Sign out
          </Button>
        </header>
        <div className="flex-1 overflow-y-auto p-6 md:p-8">
          <Outlet />
        </div>
      </main>
    </div>
  );
}

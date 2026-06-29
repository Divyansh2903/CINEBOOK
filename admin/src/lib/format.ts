export const inr = (n: number): string => `₹${n.toLocaleString("en-IN")}`;

export const dateTime = (d: string | Date): string =>
  new Date(d).toLocaleString("en-IN", { dateStyle: "medium", timeStyle: "short" });

export const dateOnly = (d: string | Date): string =>
  new Date(d).toLocaleDateString("en-IN", { dateStyle: "medium" });

export const toLocalInput = (d: Date): string => {
  const pad = (n: number) => String(n).padStart(2, "0");
  return `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}T${pad(d.getHours())}:${pad(d.getMinutes())}`;
};

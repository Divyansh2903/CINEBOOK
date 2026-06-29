import { buildApp } from "./app.js";
import { config } from "./config.js";
import { prisma } from "./db.js";
import { startHoldSweeper } from "./modules/holds/holds.service.js";

const app = await buildApp();
const sweeper = startHoldSweeper();

const shutdown = async (signal: string) => {
  app.log.info({ signal }, "shutting down");
  clearInterval(sweeper);
  await app.close();
  await prisma.$disconnect();
  process.exit(0);
};
process.on("SIGINT", () => void shutdown("SIGINT"));
process.on("SIGTERM", () => void shutdown("SIGTERM"));

try {
  await app.listen({ port: config.PORT, host: "0.0.0.0" });
} catch (err) {
  app.log.error(err);
  process.exit(1);
}

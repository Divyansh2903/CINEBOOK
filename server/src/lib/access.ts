import { prisma } from "../db.js";

// True if the hall manager is assigned to this screen. Admins bypass this check.
export async function userManagesScreen(userId: string, screenId: string): Promise<boolean> {
  const link = await prisma.screenManager.findUnique({
    where: { screenId_userId: { screenId, userId } },
  });
  return link !== null;
}

export class AppError extends Error {
  readonly statusCode: number;
  readonly details?: unknown;

  constructor(statusCode: number, message: string, details?: unknown) {
    super(message);
    this.name = "AppError";
    this.statusCode = statusCode;
    if (details !== undefined) this.details = details;
  }
}

export const badRequest = (message: string, details?: unknown) => new AppError(400, message, details);
export const forbidden = (message = "Forbidden") => new AppError(403, message);
export const notFound = (message = "Not found") => new AppError(404, message);
export const conflict = (message: string, details?: unknown) => new AppError(409, message, details);

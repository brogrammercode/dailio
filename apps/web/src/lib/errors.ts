export class ApiError extends Error {
  code: string;
  status: number;
  fieldErrors?: Record<string, string[]>;

  constructor(
    message: string,
    status: number,
    code = "API_ERROR",
    fieldErrors?: Record<string, string[]>,
  ) {
    super(message);
    this.name = "ApiError";
    this.code = code;
    this.status = status;
    this.fieldErrors = fieldErrors;
  }
}

export function safeMessage(
  error: unknown,
  fallback = "Something went wrong. Please try again.",
) {
  if (error instanceof ApiError) return error.message;
  if (error instanceof Error && error.message) return error.message;
  return fallback;
}

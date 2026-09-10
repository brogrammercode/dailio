import type { Branch, Member, Organization, User } from '@prisma/client';

declare global {
  namespace Express {
    interface Request {
      /** Authenticated user (set by auth middleware) */
      user?: User;
      /** Request correlation ID */
      request_id?: string;
      /** Active organization context (set by tenant middleware) */
      organization?: Organization;
      /** Active branch context (set by tenant middleware) */
      branch?: Branch;
      /** Caller's membership in the active branch */
      member?: Member;
      /** Effective permissions for the caller in this branch */
      permissions?: Set<string>;
    }
  }
}

export {};

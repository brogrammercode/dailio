import type { Location, LocationMembership, Organization, User } from '@prisma/client';

declare global {
  namespace Express {
    interface Request {
      /** Authenticated user (set by auth middleware) */
      user?: User;
      /** Request correlation ID */
      request_id?: string;
      /** Active organization context (set by tenant middleware) */
      organization?: Organization;
      /** Active location context (set by tenant middleware) */
      location?: Location;
      /** Caller's location membership in the active location */
      location_membership?: LocationMembership;
      /** Effective permissions for the caller in this location */
      permissions?: Set<string>;
    }
  }
}

export {};

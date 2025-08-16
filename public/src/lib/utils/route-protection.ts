import { redirect } from '@sveltejs/kit';
import type { User } from '../api/auth.js';
import { canAccessRoute, requiresPasswordReset, isAccountLocked } from './permissions.js';

export interface RouteProtectionOptions {
  requireAuth?: boolean;
  requiredRole?: 'Admin' | 'Pastor' | 'Member';
  redirectTo?: string;
  allowPasswordReset?: boolean;
}

/**
 * Protect a route based on authentication and authorization requirements
 * This function should be used in +layout.server.ts or +page.server.ts files
 */
export function protectRoute(
  user: User | null,
  currentPath: string,
  options: RouteProtectionOptions = {}
): void {
  const {
    requireAuth = true,
    requiredRole,
    redirectTo = '/login',
    allowPasswordReset = false
  } = options;

  // Check if authentication is required
  if (requireAuth && !user) {
    throw redirect(302, `${redirectTo}?redirect=${encodeURIComponent(currentPath)}`);
  }

  // If user is not required, allow access
  if (!requireAuth) {
    return;
  }

  // At this point, user should exist if requireAuth is true
  if (!user) {
    throw redirect(302, redirectTo);
  }

  // Check if account is locked
  if (isAccountLocked(user)) {
    throw redirect(302, '/account-locked');
  }

  // Check if user is active
  if (!user.is_active) {
    throw redirect(302, '/account-inactive');
  }

  // Check if password reset is required
  if (requiresPasswordReset(user) && !allowPasswordReset) {
    throw redirect(302, '/reset-password');
  }

  // Check role-based access
  if (requiredRole && user.role !== requiredRole) {
    // For role hierarchy: Admin can access Pastor routes, Pastor can access Member routes
    const roleHierarchy = { Admin: 3, Pastor: 2, Member: 1 };
    const userLevel = roleHierarchy[user.role];
    const requiredLevel = roleHierarchy[requiredRole];
    
    if (userLevel < requiredLevel) {
      throw redirect(302, '/unauthorized');
    }
  }

  // Check route-specific permissions
  if (!canAccessRoute(user, currentPath)) {
    throw redirect(302, '/unauthorized');
  }
}

/**
 * Check if a user can access a route without throwing redirects
 * Useful for conditional rendering in components
 */
export function canUserAccessRoute(
  user: User | null,
  routePath: string,
  options: RouteProtectionOptions = {}
): boolean {
  const { requireAuth = true, requiredRole } = options;

  // Check authentication requirement
  if (requireAuth && !user) {
    return false;
  }

  // If no auth required, allow access
  if (!requireAuth) {
    return true;
  }

  // At this point, user should exist if requireAuth is true
  if (!user) {
    return false;
  }

  // Check if account is locked or inactive
  if (isAccountLocked(user) || !user.is_active) {
    return false;
  }

  // Check role requirement
  if (requiredRole && user.role !== requiredRole) {
    const roleHierarchy = { Admin: 3, Pastor: 2, Member: 1 };
    const userLevel = roleHierarchy[user.role];
    const requiredLevel = roleHierarchy[requiredRole];
    
    if (userLevel < requiredLevel) {
      return false;
    }
  }

  // Check route-specific permissions
  return canAccessRoute(user, routePath);
}

/**
 * Get the appropriate redirect URL after login based on user role
 */
export function getPostLoginRedirect(user: User, intendedPath?: string): string {
  // If there's an intended path and user can access it, go there
  if (intendedPath && canUserAccessRoute(user, intendedPath)) {
    return intendedPath;
  }

  // Check if password reset is required
  if (requiresPasswordReset(user)) {
    return '/reset-password';
  }

  // Default redirects based on role
  switch (user.role) {
    case 'Admin':
      return '/dashboard';
    case 'Pastor':
      return '/dashboard';
    case 'Member':
      return '/dashboard';
    default:
      return '/dashboard';
  }
}

/**
 * Middleware function for protecting API routes
 * Can be used in API endpoints to check authentication
 */
export function requireAuth(user: User | null): User {
  if (!user) {
    throw new Error('Authentication required');
  }

  if (!user.is_active) {
    throw new Error('Account is inactive');
  }

  if (isAccountLocked(user)) {
    throw new Error('Account is locked');
  }

  return user;
}

/**
 * Middleware function for requiring specific roles
 */
export function requireRole(user: User | null, role: 'Admin' | 'Pastor' | 'Member'): User {
  const authenticatedUser = requireAuth(user);

  const roleHierarchy = { Admin: 3, Pastor: 2, Member: 1 };
  const userLevel = roleHierarchy[authenticatedUser.role];
  const requiredLevel = roleHierarchy[role];

  if (userLevel < requiredLevel) {
    throw new Error(`${role} role required`);
  }

  return authenticatedUser;
}

/**
 * Utility to create route protection configs for common scenarios
 */
export const routeConfigs = {
  public: { requireAuth: false },
  authenticated: { requireAuth: true },
  adminOnly: { requireAuth: true, requiredRole: 'Admin' as const },
  pastorOrAdmin: { requireAuth: true, requiredRole: 'Pastor' as const },
  memberOnly: { requireAuth: true, requiredRole: 'Member' as const }
};
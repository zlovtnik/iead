import type { User } from '../api/auth.js';

export type UserRole = 'Admin' | 'Pastor' | 'Member';
export type Permission = 
  | 'member:read' | 'member:write' | 'member:delete'
  | 'event:read' | 'event:write' | 'event:delete'
  | 'attendance:read' | 'attendance:write'
  | 'donation:read' | 'donation:write'
  | 'tithe:read' | 'tithe:write'
  | 'volunteer:read' | 'volunteer:write'
  | 'user:read' | 'user:write' | 'user:delete'
  | 'reports:view' | 'reports:export'
  | 'admin:access';

/**
 * Permission matrix defining what each role can do
 */
const ROLE_PERMISSIONS: Record<UserRole, Permission[]> = {
  Admin: [
    // Full access to everything
    'member:read', 'member:write', 'member:delete',
    'event:read', 'event:write', 'event:delete',
    'attendance:read', 'attendance:write',
    'donation:read', 'donation:write',
    'tithe:read', 'tithe:write',
    'volunteer:read', 'volunteer:write',
    'user:read', 'user:write', 'user:delete',
    'reports:view', 'reports:export',
    'admin:access'
  ],
  Pastor: [
    // Church management but no user administration
    'member:read', 'member:write', 'member:delete',
    'event:read', 'event:write', 'event:delete',
    'attendance:read', 'attendance:write',
    'donation:read', 'donation:write',
    'tithe:read', 'tithe:write',
    'volunteer:read', 'volunteer:write',
    'reports:view', 'reports:export'
  ],
  Member: [
    // Limited access to own data and read-only access to some church data
    'member:read', // Can view member list but not edit
    'event:read', // Can view events
    'donation:read', // Can view own donations
    'tithe:read', // Can view own tithes
    'volunteer:read' // Can view volunteer opportunities
  ]
};

/**
 * Route-based permissions for navigation protection
 */
const ROUTE_PERMISSIONS: Record<string, Permission[]> = {
  '/dashboard': [], // All authenticated users
  '/members': ['member:read'],
  '/members/create': ['member:write'],
  '/events': ['event:read'],
  '/events/create': ['event:write'],
  '/attendance': ['attendance:read'],
  '/donations': ['donation:read'],
  '/tithes': ['tithe:read'],
  '/volunteers': ['volunteer:read'],
  '/users': ['user:read'],
  '/reports': ['reports:view'],
  '/admin': ['admin:access']
};

/**
 * Check if a user has a specific permission
 */
export function hasPermission(user: User | null, permission: Permission): boolean {
  if (!user || !user.is_active) return false;
  
  const rolePermissions = ROLE_PERMISSIONS[user.role];
  return rolePermissions.includes(permission);
}

/**
 * Check if a user has any of the specified permissions
 */
export function hasAnyPermission(user: User | null, permissions: Permission[]): boolean {
  if (!user || !user.is_active) return false;
  
  return permissions.some(permission => hasPermission(user, permission));
}

/**
 * Check if a user has all of the specified permissions
 */
export function hasAllPermissions(user: User | null, permissions: Permission[]): boolean {
  if (!user || !user.is_active) return false;
  
  return permissions.every(permission => hasPermission(user, permission));
}

/**
 * Check if a user can access a specific route
 */
export function canAccessRoute(user: User | null, route: string): boolean {
  if (!user || !user.is_active) return false;
  
  // Find the most specific route match
  const routeKey = Object.keys(ROUTE_PERMISSIONS)
    .filter(key => route.startsWith(key))
    .sort((a, b) => b.length - a.length)[0];
  
  if (!routeKey) {
    // If no specific route permissions defined, allow access for authenticated users
    return true;
  }
  
  const requiredPermissions = ROUTE_PERMISSIONS[routeKey];
  
  // If no permissions required for this route, allow access
  if (requiredPermissions.length === 0) return true;
  
  // Check if user has any of the required permissions
  return hasAnyPermission(user, requiredPermissions);
}

/**
 * Get all permissions for a user's role
 */
export function getUserPermissions(user: User | null): Permission[] {
  if (!user || !user.is_active) return [];
  
  return ROLE_PERMISSIONS[user.role] || [];
}

/**
 * Check if user is admin
 */
export function isAdmin(user: User | null): boolean {
  return user?.role === 'Admin' && user.is_active;
}

/**
 * Check if user is pastor or admin
 */
export function isPastorOrAdmin(user: User | null): boolean {
  return Boolean(user?.is_active && (user.role === 'Pastor' || user.role === 'Admin'));
}

/**
 * Check if user is a regular member
 */
export function isMember(user: User | null): boolean {
  return user?.role === 'Member' && user.is_active;
}

/**
 * Filter items based on user permissions
 * Useful for filtering menu items, buttons, etc.
 */
export function filterByPermission<T extends { permission?: Permission }>(
  items: T[],
  user: User | null
): T[] {
  return items.filter(item => {
    if (!item.permission) return true; // No permission required
    return hasPermission(user, item.permission);
  });
}

/**
 * Check if user needs to reset password
 */
export function requiresPasswordReset(user: User | null): boolean {
  return user?.password_reset_required === true;
}

/**
 * Check if user account is locked due to failed login attempts
 */
export function isAccountLocked(user: User | null): boolean {
  // Assuming 5 failed attempts locks the account
  return (user?.failed_login_attempts || 0) >= 5;
}
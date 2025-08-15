import { describe, it, expect } from 'vitest';
import {
  hasPermission,
  hasAnyPermission,
  hasAllPermissions,
  canAccessRoute,
  getUserPermissions,
  isAdmin,
  isPastorOrAdmin,
  isMember,
  requiresPasswordReset,
  isAccountLocked,
  filterByPermission
} from './permissions.js';
import type { User } from '../api/auth.js';

describe('Permissions', () => {
  const adminUser: User = {
    id: 1,
    username: 'admin',
    email: 'admin@example.com',
    role: 'Admin',
    is_active: true,
    failed_login_attempts: 0,
    password_reset_required: false,
    created_at: '2024-01-01T00:00:00Z'
  };

  const pastorUser: User = {
    id: 2,
    username: 'pastor',
    email: 'pastor@example.com',
    role: 'Pastor',
    is_active: true,
    failed_login_attempts: 0,
    password_reset_required: false,
    created_at: '2024-01-01T00:00:00Z'
  };

  const memberUser: User = {
    id: 3,
    username: 'member',
    email: 'member@example.com',
    role: 'Member',
    is_active: true,
    failed_login_attempts: 0,
    password_reset_required: false,
    created_at: '2024-01-01T00:00:00Z'
  };

  const inactiveUser: User = {
    ...memberUser,
    is_active: false
  };

  const lockedUser: User = {
    ...memberUser,
    failed_login_attempts: 5
  };

  describe('hasPermission', () => {
    it('should return true for admin with any permission', () => {
      expect(hasPermission(adminUser, 'member:read')).toBe(true);
      expect(hasPermission(adminUser, 'user:delete')).toBe(true);
      expect(hasPermission(adminUser, 'admin:access')).toBe(true);
    });

    it('should return true for pastor with church management permissions', () => {
      expect(hasPermission(pastorUser, 'member:read')).toBe(true);
      expect(hasPermission(pastorUser, 'member:write')).toBe(true);
      expect(hasPermission(pastorUser, 'reports:view')).toBe(true);
    });

    it('should return false for pastor with admin-only permissions', () => {
      expect(hasPermission(pastorUser, 'user:write')).toBe(false);
      expect(hasPermission(pastorUser, 'admin:access')).toBe(false);
    });

    it('should return true for member with read-only permissions', () => {
      expect(hasPermission(memberUser, 'member:read')).toBe(true);
      expect(hasPermission(memberUser, 'event:read')).toBe(true);
    });

    it('should return false for member with write permissions', () => {
      expect(hasPermission(memberUser, 'member:write')).toBe(false);
      expect(hasPermission(memberUser, 'event:write')).toBe(false);
    });

    it('should return false for inactive user', () => {
      expect(hasPermission(inactiveUser, 'member:read')).toBe(false);
    });

    it('should return false for null user', () => {
      expect(hasPermission(null, 'member:read')).toBe(false);
    });
  });

  describe('hasAnyPermission', () => {
    it('should return true if user has any of the permissions', () => {
      expect(hasAnyPermission(memberUser, ['member:write', 'member:read'])).toBe(true);
      expect(hasAnyPermission(pastorUser, ['admin:access', 'member:write'])).toBe(true);
    });

    it('should return false if user has none of the permissions', () => {
      expect(hasAnyPermission(memberUser, ['member:write', 'admin:access'])).toBe(false);
    });
  });

  describe('hasAllPermissions', () => {
    it('should return true if user has all permissions', () => {
      expect(hasAllPermissions(adminUser, ['member:read', 'member:write'])).toBe(true);
      expect(hasAllPermissions(memberUser, ['member:read', 'event:read'])).toBe(true);
    });

    it('should return false if user is missing any permission', () => {
      expect(hasAllPermissions(memberUser, ['member:read', 'member:write'])).toBe(false);
    });
  });

  describe('canAccessRoute', () => {
    it('should allow access to dashboard for all authenticated users', () => {
      expect(canAccessRoute(adminUser, '/dashboard')).toBe(true);
      expect(canAccessRoute(pastorUser, '/dashboard')).toBe(true);
      expect(canAccessRoute(memberUser, '/dashboard')).toBe(true);
    });

    it('should allow admin access to user management', () => {
      expect(canAccessRoute(adminUser, '/users')).toBe(true);
    });

    it('should deny pastor access to user management', () => {
      expect(canAccessRoute(pastorUser, '/users')).toBe(false);
    });

    it('should deny member access to user management', () => {
      expect(canAccessRoute(memberUser, '/users')).toBe(false);
    });

    it('should allow pastor and admin access to reports', () => {
      expect(canAccessRoute(adminUser, '/reports')).toBe(true);
      expect(canAccessRoute(pastorUser, '/reports')).toBe(true);
    });

    it('should deny member access to reports', () => {
      expect(canAccessRoute(memberUser, '/reports')).toBe(false);
    });

    it('should deny access for inactive users', () => {
      expect(canAccessRoute(inactiveUser, '/dashboard')).toBe(false);
    });

    it('should deny access for null user', () => {
      expect(canAccessRoute(null, '/dashboard')).toBe(false);
    });
  });

  describe('role checking functions', () => {
    it('should correctly identify admin users', () => {
      expect(isAdmin(adminUser)).toBe(true);
      expect(isAdmin(pastorUser)).toBe(false);
      expect(isAdmin(memberUser)).toBe(false);
      expect(isAdmin(inactiveUser)).toBe(false);
    });

    it('should correctly identify pastor or admin users', () => {
      expect(isPastorOrAdmin(adminUser)).toBe(true);
      expect(isPastorOrAdmin(pastorUser)).toBe(true);
      expect(isPastorOrAdmin(memberUser)).toBe(false);
    });

    it('should correctly identify member users', () => {
      expect(isMember(adminUser)).toBe(false);
      expect(isMember(pastorUser)).toBe(false);
      expect(isMember(memberUser)).toBe(true);
    });
  });

  describe('account status checks', () => {
    it('should detect password reset requirement', () => {
      const userNeedsReset: User = {
        ...memberUser,
        password_reset_required: true
      };
      expect(requiresPasswordReset(userNeedsReset)).toBe(true);
      expect(requiresPasswordReset(memberUser)).toBe(false);
    });

    it('should detect locked accounts', () => {
      expect(isAccountLocked(lockedUser)).toBe(true);
      expect(isAccountLocked(memberUser)).toBe(false);
    });
  });

  describe('filterByPermission', () => {
    it('should filter items based on user permissions', () => {
      const items = [
        { name: 'Dashboard', permission: undefined },
        { name: 'Members', permission: 'member:read' as const },
        { name: 'Admin Panel', permission: 'admin:access' as const }
      ];

      const memberFiltered = filterByPermission(items, memberUser);
      expect(memberFiltered).toHaveLength(2);
      expect(memberFiltered.map(i => i.name)).toEqual(['Dashboard', 'Members']);

      const adminFiltered = filterByPermission(items, adminUser);
      expect(adminFiltered).toHaveLength(3);
    });
  });

  describe('getUserPermissions', () => {
    it('should return all permissions for admin', () => {
      const permissions = getUserPermissions(adminUser);
      expect(permissions).toContain('admin:access');
      expect(permissions).toContain('user:write');
      expect(permissions).toContain('member:write');
    });

    it('should return limited permissions for member', () => {
      const permissions = getUserPermissions(memberUser);
      expect(permissions).toContain('member:read');
      expect(permissions).not.toContain('member:write');
      expect(permissions).not.toContain('admin:access');
    });

    it('should return empty array for null user', () => {
      const permissions = getUserPermissions(null);
      expect(permissions).toEqual([]);
    });
  });
});
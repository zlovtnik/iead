/**
 * Example usage of the authentication system
 * This file demonstrates how to use the auth store and utilities
 */

import { auth, user, isAuthenticated, isLoading } from '../stores/auth.js';
import { hasPermission, canAccessRoute, isPastorOrAdmin } from '../utils/permissions.js';
import { protectRoute, canUserAccessRoute } from '../utils/route-protection.js';
import type { User } from '../api/auth.js';

// Example 1: Using the auth store in a Svelte component
export function exampleComponentUsage() {
  // Subscribe to auth state
  const unsubscribe = auth.subscribe(state => {
    console.log('Auth state changed:', state);
  });

  // Or use derived stores
  const unsubscribeUser = user.subscribe(currentUser => {
    console.log('Current user:', currentUser);
  });

  // Login example
  async function handleLogin(username: string, password: string) {
    try {
      await auth.login({ username, password });
      console.log('Login successful');
    } catch (error) {
      console.error('Login failed:', error);
    }
  }

  // Logout example
  async function handleLogout() {
    try {
      await auth.logout();
      console.log('Logout successful');
    } catch (error) {
      console.error('Logout failed:', error);
    }
  }

  // Initialize auth on app startup
  async function initializeAuth() {
    try {
      await auth.init();
      console.log('Auth initialized');
    } catch (error) {
      console.error('Auth initialization failed:', error);
    }
  }

  // Clean up subscriptions
  return () => {
    unsubscribe();
    unsubscribeUser();
  };
}

// Example 2: Using permissions in components
export function examplePermissionUsage(currentUser: User | null) {
  // Check if user can perform specific actions
  const canEditMembers = hasPermission(currentUser, 'member:write');
  const canAccessAdmin = hasPermission(currentUser, 'admin:access');
  const canViewReports = hasPermission(currentUser, 'reports:view');

  // Check role-based access
  const isStaff = isPastorOrAdmin(currentUser);

  // Check route access
  const canAccessUserManagement = canAccessRoute(currentUser, '/users');

  return {
    canEditMembers,
    canAccessAdmin,
    canViewReports,
    isStaff,
    canAccessUserManagement
  };
}

// Example 3: Route protection in +layout.server.ts
export function exampleRouteProtection(user: User | null, url: URL) {
  const pathname = url.pathname;

  try {
    // Protect different routes with different requirements
    if (pathname.startsWith('/admin')) {
      protectRoute(user, pathname, { requiredRole: 'Admin' });
    } else if (pathname.startsWith('/users')) {
      protectRoute(user, pathname, { requiredRole: 'Admin' });
    } else if (pathname.startsWith('/reports')) {
      protectRoute(user, pathname, { requiredRole: 'Pastor' });
    } else if (pathname.startsWith('/dashboard')) {
      protectRoute(user, pathname, { requireAuth: true });
    } else if (pathname === '/login') {
      protectRoute(user, pathname, { requireAuth: false });
    }
  } catch (redirect) {
    // SvelteKit will handle the redirect
    throw redirect;
  }
}

// Example 4: Conditional rendering based on permissions
export function exampleConditionalRendering(currentUser: User | null) {
  // Menu items with permission requirements
  const menuItems = [
    { name: 'Dashboard', path: '/dashboard', permission: undefined },
    { name: 'Members', path: '/members', permission: 'member:read' as const },
    { name: 'Events', path: '/events', permission: 'event:read' as const },
    { name: 'Reports', path: '/reports', permission: 'reports:view' as const },
    { name: 'User Management', path: '/users', permission: 'user:read' as const },
    { name: 'Admin Panel', path: '/admin', permission: 'admin:access' as const }
  ];

  // Filter menu items based on user permissions
  const visibleMenuItems = menuItems.filter(item => {
    if (!item.permission) return true; // No permission required
    return hasPermission(currentUser, item.permission);
  });

  return visibleMenuItems;
}

// Example 5: API call with automatic token handling
export async function exampleApiCall() {
  // The API client automatically handles token attachment and refresh
  // You just need to make sure the user is authenticated
  
  const currentUser = auth.subscribe(state => state.user);
  
  if (!currentUser) {
    throw new Error('User not authenticated');
  }

  // Make API calls - tokens are handled automatically
  try {
    // This would use the apiClient which handles auth automatically
    console.log('Making authenticated API call...');
  } catch (error) {
    console.error('API call failed:', error);
    // If it's an auth error, the interceptor will handle token refresh
  }
}

// Example 6: Form validation with role-based field access
export function exampleFormValidation(currentUser: User | null, formData: any) {
  const errors: Record<string, string> = {};

  // Basic validation
  if (!formData.name) {
    errors.name = 'Name is required';
  }

  // Role-based field validation
  if (formData.salary && !hasPermission(currentUser, 'member:write')) {
    errors.salary = 'You do not have permission to set salary';
  }

  if (formData.role && !hasPermission(currentUser, 'user:write')) {
    errors.role = 'You do not have permission to assign roles';
  }

  return {
    isValid: Object.keys(errors).length === 0,
    errors
  };
}

// Example 7: Reactive auth state in Svelte component
export const svelteComponentExample = `
<script lang="ts">
  import { auth, user, isAuthenticated, isLoading } from '$lib/stores/auth';
  import { hasPermission } from '$lib/utils/permissions';
  
  // Reactive statements
  $: canEditMembers = hasPermission($user, 'member:write');
  $: isStaff = $user?.role === 'Admin' || $user?.role === 'Pastor';
  
  async function handleLogin() {
    try {
      await auth.login({ username: 'admin', password: 'password' });
    } catch (error) {
      console.error('Login failed:', error);
    }
  }
</script>

{#if $isLoading}
  <div>Loading...</div>
{:else if $isAuthenticated}
  <div>Welcome, {$user?.username}!</div>
  
  {#if canEditMembers}
    <button>Edit Members</button>
  {/if}
  
  {#if isStaff}
    <a href="/reports">View Reports</a>
  {/if}
  
  <button on:click={() => auth.logout()}>Logout</button>
{:else}
  <button on:click={handleLogin}>Login</button>
{/if}
`;

export default {
  exampleComponentUsage,
  examplePermissionUsage,
  exampleRouteProtection,
  exampleConditionalRendering,
  exampleApiCall,
  exampleFormValidation,
  svelteComponentExample
};
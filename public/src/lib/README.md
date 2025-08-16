# Church Management System - Frontend Library

This directory contains the core library components for the Church Management System frontend, built with Svelte 5 and TypeScript.

## Authentication System

The authentication system provides secure user authentication, authorization, and session management with JWT tokens.

### Key Components

#### 1. Auth Store (`stores/auth.ts`)
Central state management for authentication with reactive Svelte stores.

**Features:**
- JWT token management with automatic refresh
- User session persistence
- Loading and error states
- Automatic logout on token expiration

**Usage:**
```typescript
import { auth, user, isAuthenticated } from '$lib/stores/auth';

// Login
await auth.login({ username: 'admin', password: 'password' });

// Logout
await auth.logout();

// Initialize on app startup
await auth.init();

// Subscribe to auth state
const unsubscribe = auth.subscribe(state => {
  console.log('Auth state:', state);
});
```

#### 2. Token Storage (`utils/token-storage.ts`)
Secure token management with localStorage fallback and error handling.

**Features:**
- Secure token storage and retrieval
- Automatic cleanup on logout
- Browser environment detection
- Error handling for storage failures

#### 3. Permissions System (`utils/permissions.ts`)
Role-based access control with granular permissions.

**Roles:**
- **Admin**: Full system access including user management
- **Pastor**: Church management without user administration
- **Member**: Limited access to own data and read-only church data

**Usage:**
```typescript
import { hasPermission, canAccessRoute, isPastorOrAdmin } from '$lib/utils/permissions';

// Check specific permissions
const canEdit = hasPermission(user, 'member:write');

// Check route access
const canViewReports = canAccessRoute(user, '/reports');

// Role checks
const isStaff = isPastorOrAdmin(user);
```

#### 4. Route Protection (`utils/route-protection.ts`)
Server-side route protection for SvelteKit applications.

**Usage in `+layout.server.ts`:**
```typescript
import { protectRoute } from '$lib/utils/route-protection';

export async function load({ locals, url }) {
  const user = locals.user; // From your auth middleware
  
  // Protect admin routes
  if (url.pathname.startsWith('/admin')) {
    protectRoute(user, url.pathname, { requiredRole: 'Admin' });
  }
  
  return { user };
}
```

### API Integration

#### HTTP Client (`api/client.ts`)
Axios-based HTTP client with automatic token handling and refresh.

**Features:**
- Automatic token attachment to requests
- Token refresh on 401 errors
- Request/response interceptors
- Error handling and retry logic

#### Auth API (`api/auth.ts`)
Authentication API endpoints with TypeScript interfaces.

**Available Methods:**
- `AuthApi.login(credentials)` - User authentication
- `AuthApi.logout()` - User logout
- `AuthApi.refresh(token)` - Token refresh
- `AuthApi.me()` - Get current user info
- `AuthApi.changePassword()` - Password change
- `AuthApi.resetPassword()` - Password reset

### Permission Matrix

| Permission | Admin | Pastor | Member |
|------------|-------|--------|--------|
| member:read | ✓ | ✓ | ✓ |
| member:write | ✓ | ✓ | ✗ |
| member:delete | ✓ | ✓ | ✗ |
| event:read | ✓ | ✓ | ✓ |
| event:write | ✓ | ✓ | ✗ |
| reports:view | ✓ | ✓ | ✗ |
| user:write | ✓ | ✗ | ✗ |
| admin:access | ✓ | ✗ | ✗ |

### Security Features

1. **JWT Token Management**
   - Secure token storage
   - Automatic refresh before expiration
   - Proper cleanup on logout

2. **Route Protection**
   - Server-side route guards
   - Role-based access control
   - Automatic redirects for unauthorized access

3. **Input Validation**
   - Client-side validation with Zod schemas
   - Server-side validation integration
   - XSS prevention

4. **Error Handling**
   - Graceful error recovery
   - User-friendly error messages
   - Automatic retry mechanisms

### Testing

The authentication system includes comprehensive tests:

- **Unit Tests**: Store logic, utilities, permissions
- **Integration Tests**: API client, token refresh
- **Component Tests**: Auth-related components

Run tests with:
```bash
npm test
```

### Usage Examples

See `examples/auth-usage.ts` for detailed usage examples including:
- Component integration
- Permission checking
- Route protection
- Conditional rendering
- API calls with authentication

### Best Practices

1. **Initialize auth on app startup**:
   ```typescript
   // In your root layout
   onMount(async () => {
     await auth.init();
   });
   ```

2. **Use reactive statements for permissions**:
   ```typescript
   $: canEdit = hasPermission($user, 'member:write');
   ```

3. **Protect sensitive routes**:
   ```typescript
   // In +layout.server.ts
   protectRoute(user, pathname, { requiredRole: 'Admin' });
   ```

4. **Handle loading states**:
   ```svelte
   {#if $isLoading}
     <LoadingSpinner />
   {:else if $isAuthenticated}
     <!-- Authenticated content -->
   {:else}
     <LoginForm />
   {/if}
   ```

5. **Clean up subscriptions**:
   ```typescript
   onDestroy(() => {
     unsubscribe();
   });
   ```

This authentication system provides a solid foundation for secure, role-based access control in the Church Management System frontend.
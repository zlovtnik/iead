import { writable, derived, get } from 'svelte/store';
import { browser } from '$app/environment';
import { AuthApi, type User } from '../api/auth.js';
import type { LoginCredentials } from '../api/types.js';
import { TokenStorage } from '../utils/token-storage.js';
import { ApiException } from '../api/types.js';

export interface AuthState {
  user: User | null;
  isAuthenticated: boolean;
  isLoading: boolean;
  error: string | null;
  isInitialized: boolean;
}

const initialState: AuthState = {
  user: null,
  isAuthenticated: false,
  isLoading: false,
  error: null,
  isInitialized: false
};

// Create the writable store
const authStore = writable<AuthState>(initialState);

/**
 * Authentication store with actions for login, logout, and token management
 */
export const auth = {
  // Subscribe to the store
  subscribe: authStore.subscribe,

  /**
   * Initialize the auth store by checking for existing tokens
   * Should be called on app startup
   */
  async init(): Promise<void> {
    if (!browser) return;

    authStore.update(state => ({ ...state, isLoading: true }));

    try {
      // Check if we have stored tokens
      if (TokenStorage.hasValidTokens()) {
        const storedUser = TokenStorage.getUser();
        
        if (storedUser) {
          // Try to verify the user is still valid
          try {
            const currentUser = await AuthApi.me();
            authStore.update(state => ({
              ...state,
              user: currentUser,
              isAuthenticated: true,
              isLoading: false,
              error: null,
              isInitialized: true
            }));
            
            // Update stored user data
            TokenStorage.setUser(currentUser);
          } catch (error) {
            // Token might be invalid, try to refresh
            await this.refreshToken();
          }
        } else {
          // We have tokens but no user data, fetch user
          try {
            const currentUser = await AuthApi.me();
            authStore.update(state => ({
              ...state,
              user: currentUser,
              isAuthenticated: true,
              isLoading: false,
              error: null,
              isInitialized: true
            }));
            
            TokenStorage.setUser(currentUser);
          } catch (error) {
            // Clear invalid tokens
            this.clearAuth();
          }
        }
      } else {
        // No tokens found
        authStore.update(state => ({
          ...state,
          isLoading: false,
          isInitialized: true
        }));
      }
    } catch (error) {
      console.error('Auth initialization failed:', error);
      this.clearAuth();
    }
  },

  /**
   * Login with username and password
   */
  async login(credentials: LoginCredentials): Promise<void> {
    authStore.update(state => ({ 
      ...state, 
      isLoading: true, 
      error: null 
    }));

    try {
      const response = await AuthApi.login(credentials);
      
      // Store tokens and user data
      TokenStorage.setTokens(response.tokens);
      TokenStorage.setUser(response.user);
      
      authStore.update(state => ({
        ...state,
        user: response.user,
        isAuthenticated: true,
        isLoading: false,
        error: null
      }));
    } catch (error) {
      const errorMessage = error instanceof ApiException 
        ? error.message 
        : 'Login failed. Please try again.';
      
      authStore.update(state => ({
        ...state,
        isLoading: false,
        error: errorMessage
      }));
      
      throw error;
    }
  },

  /**
   * Logout the current user
   */
  async logout(): Promise<void> {
    authStore.update(state => ({ ...state, isLoading: true }));

    try {
      // Call logout endpoint to invalidate tokens on server
      await AuthApi.logout();
    } catch (error) {
      // Even if logout fails on server, we should clear local state
      console.warn('Server logout failed:', error);
    } finally {
      this.clearAuth();
    }
  },

  /**
   * Refresh the authentication token
   */
  async refreshToken(): Promise<void> {
    const refreshToken = TokenStorage.getRefreshToken();
    
    if (!refreshToken) {
      this.clearAuth();
      throw new Error('No refresh token available');
    }

    try {
      const response = await AuthApi.refresh(refreshToken);
      
      // Update stored tokens
      TokenStorage.setTokens(response.tokens);
      
      // Fetch updated user data
      const currentUser = await AuthApi.me();
      TokenStorage.setUser(currentUser);
      
      authStore.update(state => ({
        ...state,
        user: currentUser,
        isAuthenticated: true,
        error: null,
        isInitialized: true
      }));
    } catch (error) {
      console.error('Token refresh failed:', error);
      this.clearAuth();
      throw error;
    }
  },

  /**
   * Update user data in the store
   */
  updateUser(user: User): void {
    TokenStorage.setUser(user);
    authStore.update(state => ({
      ...state,
      user
    }));
  },

  /**
   * Clear authentication state and stored data
   */
  clearAuth(): void {
    TokenStorage.clearAll();
    authStore.update(state => ({
      ...state,
      user: null,
      isAuthenticated: false,
      isLoading: false,
      error: null,
      isInitialized: true
    }));
  },

  /**
   * Clear any error state
   */
  clearError(): void {
    authStore.update(state => ({
      ...state,
      error: null
    }));
  },

  /**
   * Check if the current user has a specific permission
   */
  hasPermission(permission: string): boolean {
    const state = get(authStore);
    if (!state.user || !state.isAuthenticated) return false;
    
    // This would integrate with your permission system
    // For now, return true for authenticated users
    return true;
  }
};

// Derived stores for common use cases
export const user = derived(authStore, $auth => $auth.user);
export const isAuthenticated = derived(authStore, $auth => $auth.isAuthenticated);
export const isLoading = derived(authStore, $auth => $auth.isLoading);
export const authError = derived(authStore, $auth => $auth.error);
export const isInitialized = derived(authStore, $auth => $auth.isInitialized);

// Listen for logout events from the API client
if (browser) {
  window.addEventListener('auth:logout', () => {
    auth.clearAuth();
  });
}

export default auth;
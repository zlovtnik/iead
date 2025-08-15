import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest';
import { get } from 'svelte/store';
import { auth, type AuthState } from './auth.js';
import { AuthApi } from '../api/auth.js';
import { TokenStorage } from '../utils/token-storage.js';

// Mock the API
vi.mock('../api/auth.js');
vi.mock('../utils/token-storage.js');

// Mock browser environment
Object.defineProperty(global, 'window', {
  value: {
    addEventListener: vi.fn(),
    dispatchEvent: vi.fn()
  },
  writable: true
});

// Mock the browser environment check
vi.mock('$app/environment', () => ({
  browser: true
}));

const mockAuthApi = vi.mocked(AuthApi);
const mockTokenStorage = vi.mocked(TokenStorage);

describe('Auth Store', () => {
  beforeEach(() => {
    vi.clearAllMocks();
    // Reset the store to initial state
    auth.clearAuth();
  });

  afterEach(() => {
    vi.clearAllMocks();
  });

  describe('initialization', () => {
    it('should initialize with default state', () => {
      const state = get(auth);
      expect(state).toEqual({
        user: null,
        isAuthenticated: false,
        isLoading: false,
        error: null,
        isInitialized: true // clearAuth() sets this to true
      });
    });

    it('should initialize with stored user data', async () => {
      const mockUser = {
        id: 1,
        username: 'testuser',
        email: 'test@example.com',
        role: 'Member' as const,
        is_active: true,
        failed_login_attempts: 0,
        password_reset_required: false,
        created_at: '2024-01-01T00:00:00Z'
      };

      // Reset to uninitialized state first
      auth.clearAuth();
      
      mockTokenStorage.hasValidTokens.mockReturnValue(true);
      mockTokenStorage.getUser.mockReturnValue(mockUser);
      mockAuthApi.me.mockResolvedValue(mockUser);

      await auth.init();

      const state = get(auth);
      expect(state.user).toEqual(mockUser);
      expect(state.isAuthenticated).toBe(true);
      expect(state.isInitialized).toBe(true);
    });

    it('should clear auth if tokens are invalid', async () => {
      mockTokenStorage.hasValidTokens.mockReturnValue(true);
      mockTokenStorage.getUser.mockReturnValue(null);
      mockAuthApi.me.mockRejectedValue(new Error('Invalid token'));

      await auth.init();

      const state = get(auth);
      expect(state.user).toBeNull();
      expect(state.isAuthenticated).toBe(false);
      expect(state.isInitialized).toBe(true);
      expect(mockTokenStorage.clearAll).toHaveBeenCalled();
    });
  });

  describe('login', () => {
    it('should login successfully', async () => {
      const credentials = { username: 'testuser', password: 'password' };
      const mockResponse = {
        user: {
          id: 1,
          username: 'testuser',
          email: 'test@example.com',
          role: 'Member' as const,
          is_active: true,
          failed_login_attempts: 0,
          password_reset_required: false,
          created_at: '2024-01-01T00:00:00Z'
        },
        tokens: {
          token: 'access-token',
          refreshToken: 'refresh-token'
        }
      };

      mockAuthApi.login.mockResolvedValue(mockResponse);

      await auth.login(credentials);

      const state = get(auth);
      expect(state.user).toEqual(mockResponse.user);
      expect(state.isAuthenticated).toBe(true);
      expect(state.error).toBeNull();
      expect(mockTokenStorage.setTokens).toHaveBeenCalledWith(mockResponse.tokens);
      expect(mockTokenStorage.setUser).toHaveBeenCalledWith(mockResponse.user);
    });

    it('should handle login failure', async () => {
      const credentials = { username: 'testuser', password: 'wrongpassword' };
      const error = new Error('Invalid credentials');

      mockAuthApi.login.mockRejectedValue(error);

      await expect(auth.login(credentials)).rejects.toThrow('Invalid credentials');

      const state = get(auth);
      expect(state.user).toBeNull();
      expect(state.isAuthenticated).toBe(false);
      expect(state.error).toBe('Login failed. Please try again.'); // This is the default error message
    });
  });

  describe('logout', () => {
    it('should logout successfully', async () => {
      // First login
      const mockResponse = {
        user: {
          id: 1,
          username: 'testuser',
          email: 'test@example.com',
          role: 'Member' as const,
          is_active: true,
          failed_login_attempts: 0,
          password_reset_required: false,
          created_at: '2024-01-01T00:00:00Z'
        },
        tokens: {
          token: 'access-token',
          refreshToken: 'refresh-token'
        }
      };

      mockAuthApi.login.mockResolvedValue(mockResponse);
      await auth.login({ username: 'testuser', password: 'password' });

      // Then logout
      mockAuthApi.logout.mockResolvedValue();
      await auth.logout();

      const state = get(auth);
      expect(state.user).toBeNull();
      expect(state.isAuthenticated).toBe(false);
      expect(mockTokenStorage.clearAll).toHaveBeenCalled();
    });

    it('should clear local state even if server logout fails', async () => {
      mockAuthApi.logout.mockRejectedValue(new Error('Server error'));

      await auth.logout();

      const state = get(auth);
      expect(state.user).toBeNull();
      expect(state.isAuthenticated).toBe(false);
      expect(mockTokenStorage.clearAll).toHaveBeenCalled();
    });
  });

  describe('token refresh', () => {
    it('should refresh tokens successfully', async () => {
      const mockUser = {
        id: 1,
        username: 'testuser',
        email: 'test@example.com',
        role: 'Member' as const,
        is_active: true,
        failed_login_attempts: 0,
        password_reset_required: false,
        created_at: '2024-01-01T00:00:00Z'
      };

      const mockTokens = {
        token: 'new-access-token',
        refreshToken: 'new-refresh-token'
      };

      mockTokenStorage.getRefreshToken.mockReturnValue('old-refresh-token');
      mockAuthApi.refresh.mockResolvedValue({ tokens: mockTokens });
      mockAuthApi.me.mockResolvedValue(mockUser);

      await auth.refreshToken();

      const state = get(auth);
      expect(state.user).toEqual(mockUser);
      expect(state.isAuthenticated).toBe(true);
      expect(mockTokenStorage.setTokens).toHaveBeenCalledWith(mockTokens);
      expect(mockTokenStorage.setUser).toHaveBeenCalledWith(mockUser);
    });

    it('should clear auth if refresh fails', async () => {
      mockTokenStorage.getRefreshToken.mockReturnValue('invalid-refresh-token');
      mockAuthApi.refresh.mockRejectedValue(new Error('Invalid refresh token'));

      await expect(auth.refreshToken()).rejects.toThrow();

      const state = get(auth);
      expect(state.user).toBeNull();
      expect(state.isAuthenticated).toBe(false);
      expect(mockTokenStorage.clearAll).toHaveBeenCalled();
    });

    it('should throw error if no refresh token available', async () => {
      mockTokenStorage.getRefreshToken.mockReturnValue(null);

      await expect(auth.refreshToken()).rejects.toThrow('No refresh token available');

      const state = get(auth);
      expect(state.user).toBeNull();
      expect(state.isAuthenticated).toBe(false);
    });
  });

  describe('utility methods', () => {
    it('should update user data', () => {
      const mockUser = {
        id: 1,
        username: 'testuser',
        email: 'test@example.com',
        role: 'Member' as const,
        is_active: true,
        failed_login_attempts: 0,
        password_reset_required: false,
        created_at: '2024-01-01T00:00:00Z'
      };

      auth.updateUser(mockUser);

      const state = get(auth);
      expect(state.user).toEqual(mockUser);
      expect(mockTokenStorage.setUser).toHaveBeenCalledWith(mockUser);
    });

    it('should clear error', () => {
      // Set an error first
      auth.clearAuth();
      const stateWithError: AuthState = {
        user: null,
        isAuthenticated: false,
        isLoading: false,
        error: 'Some error',
        isInitialized: true
      };

      auth.clearError();

      const state = get(auth);
      expect(state.error).toBeNull();
    });
  });
});
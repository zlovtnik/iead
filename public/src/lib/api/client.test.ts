import { describe, it, expect, vi, beforeEach } from 'vitest';
import { ApiException } from './types.js';

// Mock localStorage
const localStorageMock = {
  getItem: vi.fn(),
  setItem: vi.fn(),
  removeItem: vi.fn(),
  clear: vi.fn(),
};

Object.defineProperty(window, 'localStorage', {
  value: localStorageMock
});

// Import after mocking
const { TokenStorage } = await import('../utils/token-storage.js');

describe('ApiClient Types and Utilities', () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  describe('TokenStorage', () => {
    it('should store and retrieve tokens', () => {
      const tokens = {
        token: 'access-token',
        refreshToken: 'refresh-token'
      };

      TokenStorage.setTokens(tokens);

      expect(localStorageMock.setItem).toHaveBeenCalledWith('church_mgmt_auth_token', 'access-token');
      expect(localStorageMock.setItem).toHaveBeenCalledWith('church_mgmt_refresh_token', 'refresh-token');
    });

    it('should retrieve stored tokens', () => {
      localStorageMock.getItem.mockImplementation((key) => {
        if (key === 'church_mgmt_auth_token') return 'stored-access-token';
        if (key === 'church_mgmt_refresh_token') return 'stored-refresh-token';
        return null;
      });

      const token = TokenStorage.getToken();
      const refreshToken = TokenStorage.getRefreshToken();

      expect(token).toBe('stored-access-token');
      expect(refreshToken).toBe('stored-refresh-token');
    });

    it('should clear tokens', () => {
      TokenStorage.clearAll();

      expect(localStorageMock.removeItem).toHaveBeenCalledWith('church_mgmt_auth_token');
      expect(localStorageMock.removeItem).toHaveBeenCalledWith('church_mgmt_refresh_token');
      expect(localStorageMock.removeItem).toHaveBeenCalledWith('church_mgmt_user');
    });
  });

  describe('ApiException', () => {
    it('should create exception with error details', () => {
      const error = {
        type: 'validation' as const,
        message: 'Validation failed',
        statusCode: 422,
        details: { name: ['Name is required'] }
      };

      const exception = new ApiException(error);

      expect(exception.name).toBe('ApiException');
      expect(exception.message).toBe('Validation failed');
      expect(exception.type).toBe('validation');
      expect(exception.statusCode).toBe(422);
      expect(exception.details).toEqual({ name: ['Name is required'] });
    });
  });
});
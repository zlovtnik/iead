import type { AuthTokens } from '../api/types.js';

/**
 * Utility class for managing JWT tokens in localStorage
 * Handles token storage, retrieval, and cleanup with proper error handling
 */
export class TokenStorage {
  private static readonly TOKEN_KEY = 'church_mgmt_auth_token';
  private static readonly REFRESH_TOKEN_KEY = 'church_mgmt_refresh_token';
  private static readonly USER_KEY = 'church_mgmt_user';

  /**
   * Get the current access token
   */
  static getToken(): string | null {
    if (typeof window === 'undefined') return null;
    
    try {
      return localStorage.getItem(this.TOKEN_KEY);
    } catch (error) {
      console.warn('Failed to get token from localStorage:', error);
      return null;
    }
  }

  /**
   * Get the current refresh token
   */
  static getRefreshToken(): string | null {
    if (typeof window === 'undefined') return null;
    
    try {
      return localStorage.getItem(this.REFRESH_TOKEN_KEY);
    } catch (error) {
      console.warn('Failed to get refresh token from localStorage:', error);
      return null;
    }
  }

  /**
   * Get stored user data
   */
  static getUser(): any | null {
    if (typeof window === 'undefined') return null;
    
    try {
      const userData = localStorage.getItem(this.USER_KEY);
      return userData ? JSON.parse(userData) : null;
    } catch (error) {
      console.warn('Failed to get user from localStorage:', error);
      return null;
    }
  }

  /**
   * Store authentication tokens
   */
  static setTokens(tokens: AuthTokens): void {
    if (typeof window === 'undefined') return;
    
    try {
      localStorage.setItem(this.TOKEN_KEY, tokens.token);
      localStorage.setItem(this.REFRESH_TOKEN_KEY, tokens.refreshToken);
    } catch (error) {
      console.error('Failed to store tokens in localStorage:', error);
    }
  }

  /**
   * Store user data
   */
  static setUser(user: any): void {
    if (typeof window === 'undefined') return;
    
    try {
      localStorage.setItem(this.USER_KEY, JSON.stringify(user));
    } catch (error) {
      console.error('Failed to store user in localStorage:', error);
    }
  }

  /**
   * Clear all stored authentication data
   */
  static clearAll(): void {
    if (typeof window === 'undefined') return;
    
    try {
      localStorage.removeItem(this.TOKEN_KEY);
      localStorage.removeItem(this.REFRESH_TOKEN_KEY);
      localStorage.removeItem(this.USER_KEY);
    } catch (error) {
      console.error('Failed to clear tokens from localStorage:', error);
    }
  }

  /**
   * Check if user is authenticated (has valid tokens)
   */
  static hasValidTokens(): boolean {
    const token = this.getToken();
    const refreshToken = this.getRefreshToken();
    return !!(token && refreshToken);
  }

  /**
   * Check if access token is expired (basic check without JWT parsing)
   * This is a simple check - in production you might want to parse the JWT
   */
  static isTokenExpired(): boolean {
    const token = this.getToken();
    if (!token) return true;

    try {
      // Simple JWT payload extraction (not cryptographically verified)
      const payload = JSON.parse(atob(token.split('.')[1]));
      const currentTime = Math.floor(Date.now() / 1000);
      return payload.exp < currentTime;
    } catch (error) {
      // If we can't parse the token, consider it expired
      return true;
    }
  }
}
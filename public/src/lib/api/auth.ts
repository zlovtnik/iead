import { apiClient } from './client.js';
import type { LoginCredentials, AuthTokens } from './types.js';

export interface User {
  id: number;
  username: string;
  email: string;
  role: 'Admin' | 'Pastor' | 'Member';
  member_id?: number;
  is_active: boolean;
  failed_login_attempts: number;
  last_login?: string;
  password_reset_required: boolean;
  created_at: string;
}

export interface LoginResponse {
  user: User;
  tokens: AuthTokens;
}

export interface RefreshResponse {
  tokens: AuthTokens;
}

export class AuthApi {
  /**
   * Authenticate user with credentials
   */
  static async login(credentials: LoginCredentials): Promise<LoginResponse> {
		console.log('Logging in...');
    return apiClient.post<LoginResponse>('/auth/login', credentials);
  }

  /**
   * Logout current user
   */
  static async logout(): Promise<void> {

    return apiClient.post<void>('/auth/logout');
  }

  /**
   * Refresh authentication tokens
   */
  static async refresh(refreshToken: string): Promise<RefreshResponse> {
    return apiClient.post<RefreshResponse>('/auth/refresh', { refreshToken });
  }

  /**
   * Get current authenticated user information
   */
  static async me(): Promise<User> {
    return apiClient.get<User>('/auth/me');
  }

  /**
   * Request password reset
   */
  static async requestPasswordReset(email: string): Promise<void> {
    return apiClient.post<void>('/auth/password-reset', { email });
  }

  /**
   * Reset password with token
   */
  static async resetPassword(token: string, newPassword: string): Promise<void> {
    return apiClient.post<void>('/auth/password-reset/confirm', {
      token,
      newPassword
    });
  }

  /**
   * Change current user's password
   */
  static async changePassword(currentPassword: string, newPassword: string): Promise<void> {
    return apiClient.post<void>('/auth/password', {
      currentPassword,
      newPassword
    });
  }
}
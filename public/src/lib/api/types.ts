// Base API response types and error handling utilities

export interface ApiResponse<T = any> {
  data: T;
  message?: string;
  success: boolean;
}

export interface ApiError {
  type: 'network' | 'validation' | 'authorization' | 'server';
  message: string;
  details?: Record<string, string[]>;
  statusCode?: number;
}

export interface ValidationError {
  field: string;
  message: string;
  code: string;
}

export interface PaginatedResponse<T> {
  data: T[];
  pagination: {
    page: number;
    limit: number;
    total: number;
    totalPages: number;
  };
}

export interface LoginCredentials {
  username: string;
  password: string;
}

export interface AuthTokens {
  token: string;
  refreshToken: string;
}

export interface RefreshTokenRequest {
  refreshToken: string;
}

export class ApiException extends Error {
  public readonly type: ApiError['type'];
  public readonly statusCode?: number;
  public readonly details?: Record<string, string[]>;

  constructor(error: ApiError) {
    super(error.message);
    this.name = 'ApiException';
    this.type = error.type;
    this.statusCode = error.statusCode;
    this.details = error.details;
  }
}
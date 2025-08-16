import axios, { 
  type AxiosInstance, 
  type AxiosRequestConfig, 
  type AxiosResponse,
  type AxiosError 
} from 'axios';
import { ApiException, type ApiError, type ApiResponse, type AuthTokens, type RefreshTokenRequest } from './types.js';
import { TokenStorage } from '../utils/token-storage.js';
import { env } from '$env/dynamic/public';

export interface ApiClient {
  get<T>(url: string, config?: AxiosRequestConfig): Promise<T>;
  post<T>(url: string, data?: any, config?: AxiosRequestConfig): Promise<T>;
  put<T>(url: string, data?: any, config?: AxiosRequestConfig): Promise<T>;
  delete<T>(url: string, config?: AxiosRequestConfig): Promise<T>;
  patch<T>(url: string, data?: any, config?: AxiosRequestConfig): Promise<T>;
}

class HttpClient implements ApiClient {
  private readonly axiosInstance: AxiosInstance;
  private isRefreshing = false;
  private failedQueue: Array<{
    resolve: (value: any) => void;
    reject: (error: any) => void;
  }> = [];

  constructor(baseURL: string = typeof env !== 'undefined' && env.PUBLIC_API_BASE_URL ? env.PUBLIC_API_BASE_URL : 'http://localhost:8080/api/v1') {
    this.axiosInstance = axios.create({
      baseURL,
      timeout: 10000,
      headers: {
        'Content-Type': 'application/json',
      },
    });

    this.setupInterceptors();
  }

  private setupInterceptors(): void {
    // Request interceptor - add auth token
    this.axiosInstance.interceptors.request.use(
      (config) => {
        const token = TokenStorage.getToken();
        if (token) {
          config.headers.Authorization = `Bearer ${token}`;
        }
        return config;
      },
      (error) => {
        return Promise.reject(this.handleError(error));
      }
    );

    // Response interceptor - handle token refresh and errors
    this.axiosInstance.interceptors.response.use(
      (response: AxiosResponse) => {
        return response;
      },
      async (error: AxiosError) => {
        const originalRequest = error.config as AxiosRequestConfig & { _retry?: boolean };

        // Handle 401 errors with token refresh
        if (error.response?.status === 401 && !originalRequest._retry) {
          if (this.isRefreshing) {
            // If already refreshing, queue the request
            return new Promise((resolve, reject) => {
              this.failedQueue.push({ resolve, reject });
            }).then((token) => {
              if (originalRequest.headers) {
                originalRequest.headers.Authorization = `Bearer ${token}`;
              }
              return this.axiosInstance(originalRequest);
            }).catch((err) => {
              return Promise.reject(this.handleError(err));
            });
          }

          originalRequest._retry = true;
          this.isRefreshing = true;

          try {
            const refreshToken = TokenStorage.getRefreshToken();
            if (!refreshToken) {
              throw new Error('No refresh token available');
            }

            const response = await this.refreshToken(refreshToken);
            const newTokens: AuthTokens = response.data;
            
            TokenStorage.setTokens(newTokens);
            
            // Process failed queue
            this.processQueue(null, newTokens.token);
            
            // Retry original request
            if (originalRequest.headers) {
              originalRequest.headers.Authorization = `Bearer ${newTokens.token}`;
            }
            return this.axiosInstance(originalRequest);
          } catch (refreshError) {
            this.processQueue(refreshError, null);
            TokenStorage.clearTokens();
            
            // Redirect to login or emit logout event
            if (typeof window !== 'undefined') {
              window.dispatchEvent(new CustomEvent('auth:logout'));
            }
            
            return Promise.reject(this.handleError(refreshError));
          } finally {
            this.isRefreshing = false;
          }
        }

        return Promise.reject(this.handleError(error));
      }
    );
  }

  private processQueue(error: any, token: string | null): void {
    this.failedQueue.forEach(({ resolve, reject }) => {
      if (error) {
        reject(error);
      } else {
        resolve(token);
      }
    });
    
    this.failedQueue = [];
  }

  private async refreshToken(refreshToken: string): Promise<AxiosResponse<AuthTokens>> {
    const refreshRequest: RefreshTokenRequest = { refreshToken };
    return this.axiosInstance.post<AuthTokens>('/auth/refresh', refreshRequest);
  }

  private handleError(error: any): ApiException {
    if (axios.isAxiosError(error)) {
      if (error.response) {
        // Server responded with error status
        // Handle your backend's error format: { error: { message: "...", code: "..." } }
        const errorData = error.response.data;
        const errorMessage = errorData?.error?.message || errorData?.message || error.message;

        const apiError: ApiError = {
          type: this.getErrorType(error.response.status),
          message: errorMessage,
          statusCode: error.response.status,
          details: errorData?.error?.details || errorData?.details,
        };
        return new ApiException(apiError);
      } else if (error.request) {
        // Network error
        const apiError: ApiError = {
          type: 'network',
          message: 'Network error - please check your connection',
        };
        return new ApiException(apiError);
      }
    }

    // Generic error
    const apiError: ApiError = {
      type: 'server',
      message: error.message || 'An unexpected error occurred',
    };
    return new ApiException(apiError);
  }

  private getErrorType(statusCode: number): ApiError['type'] {
    if (statusCode >= 400 && statusCode < 500) {
      if (statusCode === 401 || statusCode === 403) {
        return 'authorization';
      }
      if (statusCode === 422) {
        return 'validation';
      }
      return 'validation';
    }
    return 'server';
  }

  async get<T>(url: string, config?: AxiosRequestConfig): Promise<T> {
    try {
      const response = await this.axiosInstance.get(url, config);
      // Handle your backend's response format - data might be at root level or under 'data' key
      return response.data.data || response.data;
    } catch (error) {
      console.error(`Error fetching ${url}:`, error);
      throw error;
    }
  }

  async post<T>(url: string, data?: any, config?: AxiosRequestConfig): Promise<T> {
    const response = await this.axiosInstance.post(url, data, config);
    // Handle your backend's response format - data might be at root level or under 'data' key
    return response.data.data || response.data;
  }

  async put<T>(url: string, data?: any, config?: AxiosRequestConfig): Promise<T> {
    const response = await this.axiosInstance.put(url, data, config);
    // Handle your backend's response format - data might be at root level or under 'data' key
    return response.data.data || response.data;
  }

  async patch<T>(url: string, data?: any, config?: AxiosRequestConfig): Promise<T> {
    const response = await this.axiosInstance.patch(url, data, config);
    // Handle your backend's response format - data might be at root level or under 'data' key
    return response.data.data || response.data;
  }

  async delete<T>(url: string, config?: AxiosRequestConfig): Promise<T> {
    const response = await this.axiosInstance.delete(url, config);
    // Handle your backend's response format - data might be at root level or under 'data' key
    return response.data.data || response.data;
  }
}

// Create and export singleton instance
export const apiClient = new HttpClient();

// Export TokenStorage for external use
export { TokenStorage };
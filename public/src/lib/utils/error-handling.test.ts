import { describe, it, expect, vi } from 'vitest';
import { 
  extractValidationErrors, 
  getUserFriendlyErrorMessage, 
  isRetryableError,
  retryWithBackoff,
  handleApiError
} from './error-handling.js';
import { ApiException } from '../api/types.js';

describe('Error Handling Utilities', () => {
  describe('extractValidationErrors', () => {
    it('should extract validation errors from API exception', () => {
      const error = new ApiException({
        type: 'validation',
        message: 'Validation failed',
        details: {
          name: ['Name is required', 'Name must be at least 2 characters'],
          email: ['Email is invalid']
        }
      });

      const validationErrors = extractValidationErrors(error);

      expect(validationErrors).toHaveLength(3);
      expect(validationErrors[0]).toEqual({
        field: 'name',
        message: 'Name is required',
        code: 'name_0'
      });
      expect(validationErrors[1]).toEqual({
        field: 'name',
        message: 'Name must be at least 2 characters',
        code: 'name_1'
      });
      expect(validationErrors[2]).toEqual({
        field: 'email',
        message: 'Email is invalid',
        code: 'email_0'
      });
    });

    it('should return empty array for non-validation errors', () => {
      const error = new ApiException({
        type: 'network',
        message: 'Network error'
      });

      const validationErrors = extractValidationErrors(error);

      expect(validationErrors).toHaveLength(0);
    });
  });

  describe('getUserFriendlyErrorMessage', () => {
    it('should return friendly message for network errors', () => {
      const error = new ApiException({
        type: 'network',
        message: 'Network error'
      });

      const message = getUserFriendlyErrorMessage(error);

      expect(message).toBe('Unable to connect to the server. Please check your internet connection and try again.');
    });

    it('should return friendly message for 401 authorization errors', () => {
      const error = new ApiException({
        type: 'authorization',
        message: 'Unauthorized',
        statusCode: 401
      });

      const message = getUserFriendlyErrorMessage(error);

      expect(message).toBe('Your session has expired. Please log in again.');
    });

    it('should return friendly message for 403 authorization errors', () => {
      const error = new ApiException({
        type: 'authorization',
        message: 'Forbidden',
        statusCode: 403
      });

      const message = getUserFriendlyErrorMessage(error);

      expect(message).toBe('You do not have permission to perform this action.');
    });

    it('should return friendly message for validation errors', () => {
      const error = new ApiException({
        type: 'validation',
        message: 'Validation failed'
      });

      const message = getUserFriendlyErrorMessage(error);

      expect(message).toBe('Validation failed');
    });

    it('should return friendly message for server errors', () => {
      const error = new ApiException({
        type: 'server',
        message: 'Internal server error',
        statusCode: 500
      });

      const message = getUserFriendlyErrorMessage(error);

      expect(message).toBe('A server error occurred. Please try again later.');
    });
  });

  describe('isRetryableError', () => {
    it('should return true for network errors', () => {
      const error = new ApiException({
        type: 'network',
        message: 'Network error'
      });

      expect(isRetryableError(error)).toBe(true);
    });

    it('should return true for 503 server errors', () => {
      const error = new ApiException({
        type: 'server',
        message: 'Service unavailable',
        statusCode: 503
      });

      expect(isRetryableError(error)).toBe(true);
    });

    it('should return false for validation errors', () => {
      const error = new ApiException({
        type: 'validation',
        message: 'Validation failed'
      });

      expect(isRetryableError(error)).toBe(false);
    });

    it('should return false for authorization errors', () => {
      const error = new ApiException({
        type: 'authorization',
        message: 'Unauthorized'
      });

      expect(isRetryableError(error)).toBe(false);
    });
  });

  describe('retryWithBackoff', () => {
    it('should succeed on first attempt', async () => {
      const mockFn = vi.fn().mockResolvedValue('success');

      const result = await retryWithBackoff(mockFn, 3, 100);

      expect(result).toBe('success');
      expect(mockFn).toHaveBeenCalledTimes(1);
    });

    it('should retry on retryable errors', async () => {
      const networkError = new ApiException({
        type: 'network',
        message: 'Network error'
      });
      
      const mockFn = vi.fn()
        .mockRejectedValueOnce(networkError)
        .mockRejectedValueOnce(networkError)
        .mockResolvedValue('success');

      const result = await retryWithBackoff(mockFn, 3, 10);

      expect(result).toBe('success');
      expect(mockFn).toHaveBeenCalledTimes(3);
    });

    it('should not retry on non-retryable errors', async () => {
      const validationError = new ApiException({
        type: 'validation',
        message: 'Validation failed'
      });
      
      const mockFn = vi.fn().mockRejectedValue(validationError);

      await expect(retryWithBackoff(mockFn, 3, 10)).rejects.toThrow('Validation failed');
      expect(mockFn).toHaveBeenCalledTimes(1);
    });

    it('should throw last error after max retries', async () => {
      const networkError = new ApiException({
        type: 'network',
        message: 'Network error'
      });
      
      const mockFn = vi.fn().mockRejectedValue(networkError);

      await expect(retryWithBackoff(mockFn, 2, 10)).rejects.toThrow('Network error');
      expect(mockFn).toHaveBeenCalledTimes(3); // Initial + 2 retries
    });
  });

  describe('handleApiError', () => {
    it('should return ApiException as-is', () => {
      const apiError = new ApiException({
        type: 'validation',
        message: 'Validation failed'
      });

      const result = handleApiError(apiError);

      expect(result).toBe(apiError);
    });

    it('should convert Error to ApiException', () => {
      const error = new Error('Something went wrong');

      const result = handleApiError(error);

      expect(result).toBeInstanceOf(ApiException);
      expect(result.type).toBe('server');
      expect(result.message).toBe('Something went wrong');
    });

    it('should handle unknown errors', () => {
      const result = handleApiError('unknown error');

      expect(result).toBeInstanceOf(ApiException);
      expect(result.type).toBe('server');
      expect(result.message).toBe('An unexpected error occurred');
    });
  });
});
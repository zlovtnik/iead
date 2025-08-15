import { ApiException, type ApiError, type ValidationError } from '../api/types.js';

/**
 * Extract validation errors from API error details
 */
export function extractValidationErrors(error: ApiException): ValidationError[] {
  if (error.type !== 'validation' || !error.details) {
    return [];
  }

  const validationErrors: ValidationError[] = [];
  
  for (const [field, messages] of Object.entries(error.details)) {
    messages.forEach((message, index) => {
      validationErrors.push({
        field,
        message,
        code: `${field}_${index}`
      });
    });
  }

  return validationErrors;
}

/**
 * Get user-friendly error message
 */
export function getUserFriendlyErrorMessage(error: ApiException): string {
  switch (error.type) {
    case 'network':
      return 'Unable to connect to the server. Please check your internet connection and try again.';
    
    case 'authorization':
      if (error.statusCode === 401) {
        return 'Your session has expired. Please log in again.';
      }
      if (error.statusCode === 403) {
        return 'You do not have permission to perform this action.';
      }
      return 'Authentication failed. Please log in again.';
    
    case 'validation':
      return error.message || 'Please check your input and try again.';
    
    case 'server':
      if (error.statusCode === 500) {
        return 'A server error occurred. Please try again later.';
      }
      if (error.statusCode === 503) {
        return 'The service is temporarily unavailable. Please try again later.';
      }
      return error.message || 'An unexpected error occurred. Please try again.';
    
    default:
      return error.message || 'An unexpected error occurred. Please try again.';
  }
}

/**
 * Check if error is retryable
 */
export function isRetryableError(error: ApiException): boolean {
  return error.type === 'network' || 
         (error.type === 'server' && error.statusCode === 503);
}

/**
 * Retry function with exponential backoff
 */
export async function retryWithBackoff<T>(
  fn: () => Promise<T>,
  maxRetries: number = 3,
  baseDelay: number = 1000
): Promise<T> {
  let lastError: Error;

  for (let attempt = 0; attempt <= maxRetries; attempt++) {
    try {
      return await fn();
    } catch (error) {
      lastError = error as Error;
      
      // Don't retry on last attempt
      if (attempt === maxRetries) {
        break;
      }

      // Only retry if error is retryable
      if (error instanceof ApiException && !isRetryableError(error)) {
        break;
      }

      // Calculate delay with exponential backoff
      const delay = baseDelay * Math.pow(2, attempt);
      await new Promise(resolve => setTimeout(resolve, delay));
    }
  }

  throw lastError!;
}

/**
 * Handle API errors in a consistent way
 */
export function handleApiError(error: unknown): ApiException {
  if (error instanceof ApiException) {
    return error;
  }

  if (error instanceof Error) {
    return new ApiException({
      type: 'server',
      message: error.message
    });
  }

  return new ApiException({
    type: 'server',
    message: 'An unexpected error occurred'
  });
}

/**
 * Create error handler for async operations
 */
export function createErrorHandler(
  onError?: (error: ApiException) => void
) {
  return (error: unknown) => {
    const apiError = handleApiError(error);
    
    if (onError) {
      onError(apiError);
    } else {
      console.error('API Error:', apiError);
    }
    
    return apiError;
  };
}
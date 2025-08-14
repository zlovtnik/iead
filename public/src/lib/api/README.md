# API Infrastructure

This directory contains the base HTTP client and API infrastructure for the Church Management System frontend.

## Features Implemented

### ✅ Axios-based HTTP client with TypeScript generics
- **File**: `client.ts`
- Generic HTTP methods (GET, POST, PUT, PATCH, DELETE)
- Type-safe API responses with `ApiResponse<T>` wrapper
- Configurable base URL and timeout settings

### ✅ Request/Response interceptors for authentication and error handling
- **File**: `client.ts`
- **Request Interceptor**: Automatically adds Bearer token to requests
- **Response Interceptor**: Handles token refresh and error standardization
- Comprehensive error classification (network, validation, authorization, server)

### ✅ Base API response types and error handling utilities
- **File**: `types.ts` - Core type definitions
- **File**: `error-handling.ts` - Error handling utilities
- `ApiResponse<T>` for consistent API responses
- `ApiException` for structured error handling
- `ValidationError` for form validation errors
- `PaginatedResponse<T>` for paginated data

### ✅ Token refresh mechanism with automatic retry logic
- **File**: `client.ts`
- Automatic token refresh on 401 errors
- Request queuing during token refresh
- Exponential backoff retry mechanism
- Secure token storage in localStorage
- Automatic logout on refresh failure

## Key Components

### HttpClient Class
- Singleton pattern for consistent API access
- Automatic token management
- Request/response interceptors
- Error handling and retry logic

### TokenStorage Utility
- Secure token storage and retrieval
- Token cleanup on logout
- SSR-safe implementation

### Error Handling System
- Structured error classification
- User-friendly error messages
- Retry logic for transient errors
- Validation error extraction

### Authentication API
- **File**: `auth.ts`
- Login/logout functionality
- Token refresh
- User profile retrieval
- Password reset capabilities

## Usage Examples

```typescript
import { apiClient, AuthApi, TokenStorage } from '$lib/api';

// Login
const response = await AuthApi.login({ username, password });
TokenStorage.setTokens(response.tokens);

// Make authenticated API calls
const members = await apiClient.get<Member[]>('/members');

// Handle errors
try {
  await apiClient.post('/members', memberData);
} catch (error) {
  if (error instanceof ApiException && error.type === 'validation') {
    // Handle validation errors
    console.log(error.details);
  }
}
```

## Requirements Satisfied

- **Requirement 1.2**: Automatic token refresh mechanism ✅
- **Requirement 10.3**: Proper authentication tokens and error handling ✅  
- **Requirement 10.4**: Authorization error handling and access denial ✅

## Testing

All components are thoroughly tested with unit tests:
- `client.test.ts` - HTTP client and token storage tests
- `error-handling.test.ts` - Error handling utility tests

Run tests with: `deno task test`
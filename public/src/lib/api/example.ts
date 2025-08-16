// Example usage of the API client
import { apiClient, AuthApi, TokenStorage, handleApiError, retryWithBackoff } from './index.js';

/**
 * Example: Login and handle authentication
 */
export async function loginExample() {
  try {
    const response = await AuthApi.login({
      username: 'user@example.com',
      password: 'password123'
    });

    // Store tokens
    TokenStorage.setTokens(response.tokens);

    console.log('Login successful:', response.user);
    return response.user;
  } catch (error) {
    const apiError = handleApiError(error);
    console.error('Login failed:', apiError.message);
    throw apiError;
  }
}

/**
 * Example: Make API call with retry logic
 */
export async function fetchDataWithRetry() {
  try {
    const data = await retryWithBackoff(
      () => apiClient.get('/members'),
      3, // max retries
      1000 // base delay in ms
    );

    console.log('Data fetched:', data);
    return data;
  } catch (error) {
    const apiError = handleApiError(error);
    console.error('Failed to fetch data:', apiError.message);
    throw apiError;
  }
}

/**
 * Example: Handle form submission with validation errors
 */
export async function createMemberExample(memberData: any) {
  try {
    const newMember = await apiClient.post('/members', memberData);
    console.log('Member created:', newMember);
    return newMember;
  } catch (error) {
    const apiError = handleApiError(error);
    
    if (apiError.type === 'validation') {
      console.log('Validation errors:', apiError.details);
      // Handle validation errors in UI
    } else {
      console.error('Failed to create member:', apiError.message);
    }
    
    throw apiError;
  }
}

/**
 * Example: Logout and cleanup
 */
export async function logoutExample() {
  try {
    await AuthApi.logout();
    TokenStorage.clearTokens();
    console.log('Logout successful');
  } catch (error) {
    // Even if logout fails, clear local tokens
    TokenStorage.clearTokens();
    console.error('Logout error:', error);
  }
}
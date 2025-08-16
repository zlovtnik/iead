import { redirect } from '@sveltejs/kit';
import type { LayoutServerLoad } from './$types';
import { TokenStorage } from '$lib/utils/token-storage.js';
import { AuthApi } from '$lib/api/auth.js';

export const load: LayoutServerLoad = async ({ cookies, url }) => {
  // Check for authentication token in cookies
  const token = cookies.get('auth_token');
  
  if (!token) {
    // No token found, redirect to login
    throw redirect(302, `/login?redirect=${encodeURIComponent(url.pathname)}`);
  }

  try {
    // Verify token by fetching user data
    // Note: In a real implementation, you'd validate the token server-side
    // For now, we'll let the client handle token validation
    
    return {
      user: null // Will be populated by client-side auth store
    };
  } catch (error) {
    // Token is invalid, clear it and redirect to login
    cookies.delete('auth_token', { path: '/' });
    throw redirect(302, `/login?redirect=${encodeURIComponent(url.pathname)}`);
  }
};
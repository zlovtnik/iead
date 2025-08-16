import type { LayoutServerLoad } from './$types';

export const load: LayoutServerLoad = async ({ url }) => {
  // Authentication is handled on the client side using localStorage
  // We don't try to check for authentication on the server side anymore
  
  return {
    // Will be populated by client-side auth store
    user: null 
  };
};
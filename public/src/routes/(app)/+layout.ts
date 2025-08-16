import type { LayoutLoad } from './$types';
import { browser } from '$app/environment';
import { TokenStorage } from '$lib/utils/token-storage.js';

export const load: LayoutLoad = async () => {
  if (!browser) return {};

  // Read user from localStorage; auth store will keep it in sync
  const user = TokenStorage.getUser();
  return { user };
};

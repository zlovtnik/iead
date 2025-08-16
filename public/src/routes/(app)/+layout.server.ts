import type { LayoutServerLoad } from './$types';

export const load: LayoutServerLoad = async () => {
  // Server does not expose user; client loader will provide it when available
  return {};
};
<script lang="ts">
	import { onMount } from 'svelte';
	import { goto } from '$app/navigation';
	import { isAuthenticated } from '$lib/stores/auth.js';

	onMount(() => {
		const unsubscribe = isAuthenticated.subscribe((authenticated) => {
			if (authenticated) {
				goto('/dashboard', { replaceState: true });
			} else {
				goto('/login', { replaceState: true });
			}
		});

		return unsubscribe;
	});
</script>

<div class="min-h-screen flex items-center justify-center bg-secondary-50">
	<div class="text-center">
		<div class="animate-spin rounded-full h-12 w-12 border-b-2 border-primary-600 mx-auto"></div>
		<p class="mt-4 text-secondary-600">Loading...</p>
	</div>
</div>

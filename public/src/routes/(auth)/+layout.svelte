<script lang="ts">
  import { onMount } from 'svelte';
  import { auth } from '$lib/stores/auth.js';

  let { children } = $props();

  // Initialize auth store when the app loads
  onMount(() => {
    auth.init();
  });
</script>

<!-- Auth layout - minimal styling for login/register pages -->
<div class="auth-layout">
  {@render children?.()}
</div>

<style>
  .auth-layout {
    min-height: 100vh;
    background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
  }
</style>
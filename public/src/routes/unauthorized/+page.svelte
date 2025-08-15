<script lang="ts">
  import { goto } from '$app/navigation';
  import Button from '$lib/components/ui/Button.svelte';
  import { user } from '$lib/stores/auth.js';

  function goBack() {
    history.back();
  }

  function goToDashboard() {
    goto('/dashboard');
  }
</script>

<svelte:head>
  <title>Unauthorized - Church Management System</title>
</svelte:head>

<div class="min-h-screen flex items-center justify-center bg-secondary-50 py-12 px-4 sm:px-6 lg:px-8">
  <div class="max-w-md w-full text-center">
    <!-- Error icon -->
    <div class="mx-auto flex items-center justify-center h-16 w-16 rounded-full bg-error-100">
      <svg class="h-8 w-8 text-error-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-2.5L13.732 4c-.77-.833-1.964-.833-2.732 0L4.082 16.5c-.77.833.192 2.5 1.732 2.5z" />
      </svg>
    </div>

    <!-- Error message -->
    <h1 class="mt-6 text-3xl font-extrabold text-secondary-900">
      Access Denied
    </h1>
    <p class="mt-2 text-base text-secondary-600">
      You don't have permission to access this page.
    </p>
    
    {#if $user}
      <p class="mt-2 text-sm text-secondary-500">
        Your current role: <span class="font-medium">{$user.role}</span>
      </p>
    {/if}

    <!-- Actions -->
    <div class="mt-8 flex flex-col sm:flex-row gap-3 justify-center">
      <Button variant="primary" onclick={goToDashboard}>
        Go to Dashboard
      </Button>
      <Button variant="ghost" onclick={goBack}>
        Go Back
      </Button>
    </div>
  </div>
</div>
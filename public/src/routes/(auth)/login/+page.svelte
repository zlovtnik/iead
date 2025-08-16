<script lang="ts">
  import { goto } from '$app/navigation';
  import { page } from '$app/stores';
  import { onMount } from 'svelte';
  import FormWrapper from '$lib/components/forms/FormWrapper.svelte';
  import FormField from '$lib/components/forms/FormField.svelte';
  import { loginSchema, type LoginCredentials } from '$lib/validators/auth.js';
  import { auth, isAuthenticated } from '$lib/stores/auth.js';
  import { getPostLoginRedirect } from '$lib/utils/route-protection.js';

  let loginData: LoginCredentials = {
    username: '',
    password: ''
  };

  // Redirect if already authenticated
  onMount(() => {
    return isAuthenticated.subscribe((authenticated) => {
      if (authenticated) {
        const user = auth.get().user;
        if (user) {
          const redirectTo = $page.url.searchParams.get('redirect') || getPostLoginRedirect(user);
          goto(redirectTo, { replaceState: true });
        }
      }
    });
  });

  async function handleLogin(data: LoginCredentials) {
    try {
      await auth.login(data);
      
      // Get redirect URL from query params or use default
      const redirectTo = $page.url.searchParams.get('redirect') || '/dashboard';
      console.log('Login successful, redirecting to:', redirectTo);
      setTimeout(() => {
        goto(redirectTo, { replaceState: true });
      }, 100); // Small delay to ensure auth state is updated
    } catch (error) {
      // Error is handled by the auth store and displayed in the form
      console.error('Login failed:', error);
    }
  }
</script>

<svelte:head>
  <title>Login - Church Management System</title>
</svelte:head>

<div class="min-h-screen flex items-center justify-center bg-secondary-50 py-12 px-4 sm:px-6 lg:px-8">
  <div class="max-w-md w-full space-y-8">
    <!-- Header -->
    <div class="text-center">
      <h2 class="mt-6 text-3xl font-extrabold text-secondary-900">
        Sign in to your account
      </h2>
      <p class="mt-2 text-sm text-secondary-600">
        Church Management System
      </p>
    </div>

    <!-- Login Form -->
    <div class="bg-white py-8 px-6 shadow-lg rounded-lg">
      <FormWrapper
        schema={loginSchema}
        initialData={loginData}
        onsubmit={handleLogin}
        submitText="Sign in"
        submitVariant="primary"
        class="space-y-6"
      >
        {#snippet children(form: any)}
          <div class="space-y-4">
            <FormField
              name="username"
              type="text"
              label="Username"
              required
              fullWidth
              bind:value={form.formData.username}
              error={form.errors.username}
              onchange={(value) => form.handleFieldChange('username', value)}
              onblur={(event) => {
                const target = event.target as HTMLInputElement | null;
                if (target) {
                  form.handleFieldBlur('username', target.value);
                }
              }}
              autocomplete="username"
              placeholder="Enter your username"
            />

            <FormField
              name="password"
              type="password"
              label="Password"
              required
              fullWidth
              bind:value={form.formData.password}
              error={form.errors.password}
              onchange={(value) => form.handleFieldChange('password', value)}
              onblur={(event) => {
                const target = event.target as HTMLInputElement | null;
                if (target) {
                  form.handleFieldBlur('password', target.value);
                }
              }}
              autocomplete="current-password"
              placeholder="Enter your password"
            />

            <!-- Password requirements hint -->
            {#if form.errors.password}
              <div class="text-xs text-secondary-600 mt-1">
                <p class="font-medium">Password must contain:</p>
                <ul class="list-disc list-inside mt-1 space-y-1">
                  <li>At least 8 characters</li>
                  <li>One uppercase letter</li>
                  <li>One lowercase letter</li>
                  <li>One number</li>
                </ul>
              </div>
            {/if}
          </div>

          <!-- Additional options -->
          <div class="flex items-center justify-between">
            <div class="flex items-center">
              <input
                id="remember-me"
                name="remember-me"
                type="checkbox"
                class="h-4 w-4 text-primary-600 focus:ring-primary-500 border-secondary-300 rounded"
              />
              <label for="remember-me" class="ml-2 block text-sm text-secondary-900">
                Remember me
              </label>
            </div>

            <div class="text-sm">
              <a href="/forgot-password" class="font-medium text-primary-600 hover:text-primary-500">
                Forgot your password?
              </a>
            </div>
          </div>
        {/snippet}
      </FormWrapper>
    </div>

    <!-- Footer -->
    <div class="text-center">
      <p class="text-xs text-secondary-500">
        © 2024 Church Management System. All rights reserved.
      </p>
    </div>
  </div>
</div>
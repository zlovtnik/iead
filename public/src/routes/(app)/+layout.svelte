<script lang="ts">
  import { onMount } from 'svelte';
  import { page } from '$app/stores';
  import { goto } from '$app/navigation';
  import { auth, user, isAuthenticated } from '$lib/stores/auth.js';
  import { canUserAccessRoute } from '$lib/utils/route-protection.js';
  import Button from '$lib/components/ui/Button.svelte';
  import Modal from '$lib/components/ui/Modal.svelte';

  let { children } = $props();

  // Navigation state
  let isMobileMenuOpen = $state(false);
  let isUserMenuOpen = $state(false);
  let showLogoutModal = $state(false);

  // Initialize auth and check authentication
  onMount(() => {
    auth.init();
    
    // Debug: log auth state
    console.log('Initial auth state in app layout:', auth.get());
    
    // Subscribe to auth changes and redirect if not authenticated
    const unsubscribe = isAuthenticated.subscribe((authenticated) => {
      console.log('Auth state changed:', authenticated, 'Current path:', $page.url.pathname);
      
      if (!authenticated && $page.url.pathname !== '/login') {
        console.log('Not authenticated, redirecting to login');
        goto(`/login?redirect=${encodeURIComponent($page.url.pathname)}`);
      }
    });

    return unsubscribe;
  });

  // Navigation items based on user role
  let navigationItems = $derived($user ? getNavigationItems($user.role) : getNavigationItems('Member'));

  function getNavigationItems(role: 'Admin' | 'Pastor' | 'Member') {
    const baseItems = [
      { name: 'Dashboard', href: '/dashboard', icon: 'home' },
    ];

    if (role === 'Admin' || role === 'Pastor') {
      baseItems.push(
        { name: 'Members', href: '/members', icon: 'users' },
        { name: 'Events', href: '/events', icon: 'calendar' },
        { name: 'Attendance', href: '/attendance', icon: 'check-circle' },
        { name: 'Donations', href: '/donations', icon: 'dollar-sign' },
        { name: 'Tithes', href: '/tithes', icon: 'percent' },
        { name: 'Volunteers', href: '/volunteers', icon: 'heart' },
        { name: 'Reports', href: '/reports', icon: 'bar-chart' }
      );
    }

    if (role === 'Admin') {
      baseItems.push(
        { name: 'Users', href: '/users', icon: 'user-cog' }
      );
    }

    if (role === 'Member') {
      baseItems.push(
        { name: 'My Profile', href: '/profile', icon: 'user' },
        { name: 'My Donations', href: '/my-donations', icon: 'dollar-sign' },
        { name: 'My Attendance', href: '/my-attendance', icon: 'check-circle' }
      );
    }

    return baseItems;
  }

  function toggleMobileMenu() {
    isMobileMenuOpen = !isMobileMenuOpen;
  }

  function toggleUserMenu() {
    isUserMenuOpen = !isUserMenuOpen;
  }

  function closeMobileMenu() {
    isMobileMenuOpen = false;
  }

  function closeUserMenu() {
    isUserMenuOpen = false;
  }

  async function handleLogout() {
    showLogoutModal = false;
    try {
      await auth.logout();
      goto('/login');
    } catch (error) {
      console.error('Logout failed:', error);
    }
  }

  function showLogoutConfirmation() {
    showLogoutModal = true;
    closeUserMenu();
  }

  // Close menus when clicking outside
  function handleClickOutside(event: MouseEvent) {
    const target = event.target as Element;
    
    // Close user menu if clicking outside
    if (isUserMenuOpen && !target.closest('.user-menu')) {
      closeUserMenu();
    }
    
    // Close mobile menu if clicking outside
    if (isMobileMenuOpen && !target.closest('.mobile-menu') && !target.closest('.mobile-menu-button')) {
      closeMobileMenu();
    }
  }

  onMount(() => {
    document.addEventListener('click', handleClickOutside);
    return () => document.removeEventListener('click', handleClickOutside);
  });
</script>

<svelte:head>
  <title>Church Management System</title>
</svelte:head>

<div class="min-h-screen bg-secondary-50">
  <!-- Navigation -->
  <nav class="bg-white shadow-sm border-b border-secondary-200">
    <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
      <div class="flex justify-between h-16">
        <!-- Logo and main navigation -->
        <div class="flex">
          <!-- Logo -->
          <div class="flex-shrink-0 flex items-center">
            <h1 class="text-xl font-bold text-primary-600">
              Church Management
            </h1>
          </div>

          <!-- Desktop navigation -->
          <div class="hidden md:ml-6 md:flex md:space-x-8">
            {#each navigationItems as item}
              <a
                href={item.href}
                class="inline-flex items-center px-1 pt-1 text-sm font-medium transition-colors duration-200 {
                  $page.url.pathname === item.href
                    ? 'border-b-2 border-primary-500 text-secondary-900'
                    : 'text-secondary-500 hover:text-secondary-700 hover:border-secondary-300'
                }"
                onclick={closeMobileMenu}
              >
                {item.name}
              </a>
            {/each}
          </div>
        </div>

        <!-- User menu and mobile menu button -->
        <div class="flex items-center">
          <!-- User menu -->
          {#if $user}
            <div class="relative user-menu">
              <button
                type="button"
                class="flex items-center text-sm rounded-full focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-primary-500"
                onclick={toggleUserMenu}
                aria-expanded={isUserMenuOpen}
                aria-haspopup="true"
              >
                <span class="sr-only">Open user menu</span>
                <div class="h-8 w-8 rounded-full bg-primary-600 flex items-center justify-center">
                  <span class="text-sm font-medium text-white">
                    {$user?.username?.charAt(0)?.toUpperCase() || '?'}
                  </span>
                </div>
                <span class="ml-2 text-sm font-medium text-secondary-700 hidden sm:block">
                  {$user?.username || 'User'}
                </span>
                <svg class="ml-1 h-4 w-4 text-secondary-400" fill="currentColor" viewBox="0 0 20 20">
                  <path fill-rule="evenodd" d="M5.293 7.293a1 1 0 011.414 0L10 10.586l3.293-3.293a1 1 0 111.414 1.414l-4 4a1 1 0 01-1.414 0l-4-4a1 1 0 010-1.414z" clip-rule="evenodd" />
                </svg>
              </button>

              <!-- User dropdown menu -->
              {#if isUserMenuOpen}
                <div class="origin-top-right absolute right-0 mt-2 w-48 rounded-md shadow-lg bg-white ring-1 ring-black ring-opacity-5 z-50">
                  <div class="py-1" role="menu" aria-orientation="vertical">
                    <!-- User info -->
                    <div class="px-4 py-2 text-sm text-secondary-500 border-b border-secondary-100">
                      <div class="font-medium text-secondary-900">{$user?.username || 'User'}</div>
                      <div class="text-xs">{$user?.role || 'Member'}</div>
                    </div>

                    <!-- Menu items -->
                    <a
                      href="/profile"
                      class="block px-4 py-2 text-sm text-secondary-700 hover:bg-secondary-100"
                      role="menuitem"
                      onclick={closeUserMenu}
                    >
                      Profile Settings
                    </a>
                    
                    {#if $user?.role === 'Admin'}
                      <a
                        href="/settings"
                        class="block px-4 py-2 text-sm text-secondary-700 hover:bg-secondary-100"
                        role="menuitem"
                        onclick={closeUserMenu}
                      >
                        System Settings
                      </a>
                    {/if}

                    <button
                      type="button"
                      class="block w-full text-left px-4 py-2 text-sm text-error-700 hover:bg-error-50"
                      role="menuitem"
                      onclick={showLogoutConfirmation}
                    >
                      Sign out
                    </button>
                  </div>
                </div>
              {/if}
            </div>
          {/if}

          <!-- Mobile menu button -->
          <button
            type="button"
            class="md:hidden ml-2 inline-flex items-center justify-center p-2 rounded-md text-secondary-400 hover:text-secondary-500 hover:bg-secondary-100 focus:outline-none focus:ring-2 focus:ring-inset focus:ring-primary-500 mobile-menu-button"
            onclick={toggleMobileMenu}
            aria-expanded={isMobileMenuOpen}
          >
            <span class="sr-only">Open main menu</span>
            {#if isMobileMenuOpen}
              <!-- Close icon -->
              <svg class="h-6 w-6" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
              </svg>
            {:else}
              <!-- Menu icon -->
              <svg class="h-6 w-6" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 6h16M4 12h16M4 18h16" />
              </svg>
            {/if}
          </button>
        </div>
      </div>
    </div>

    <!-- Mobile menu -->
    {#if isMobileMenuOpen}
      <div class="md:hidden mobile-menu">
        <div class="pt-2 pb-3 space-y-1 bg-white border-t border-secondary-200">
          {#each navigationItems as item}
            <a
              href={item.href}
              class="block pl-3 pr-4 py-2 text-base font-medium transition-colors duration-200 {
                $page.url.pathname === item.href
                  ? 'bg-primary-50 border-r-4 border-primary-500 text-primary-700'
                  : 'text-secondary-600 hover:text-secondary-800 hover:bg-secondary-50'
              }"
              onclick={closeMobileMenu}
            >
              {item.name}
            </a>
          {/each}
        </div>
      </div>
    {/if}
  </nav>

  <!-- Main content -->
  <main class="max-w-7xl mx-auto py-6 px-4 sm:px-6 lg:px-8">
    {@render children?.()}
  </main>

  <!-- Logout confirmation modal -->
  <Modal
    bind:open={showLogoutModal}
    title="Confirm Logout"
    size="sm"
  >
    <div class="text-sm text-secondary-600 mb-4">
      Are you sure you want to sign out? You will need to log in again to access the system.
    </div>
    
    <div class="flex justify-end space-x-3">
      <Button
        variant="ghost"
        onclick={() => showLogoutModal = false}
      >
        Cancel
      </Button>
      <Button
        variant="error"
        onclick={handleLogout}
      >
        Sign Out
      </Button>
    </div>
  </Modal>
</div>
<script lang="ts">
  import { user } from '$lib/stores/auth.js';
  import { Button } from '$lib/components/ui/index.js';
</script>

<svelte:head>
  <title>Reports - Church Management System</title>
</svelte:head>

<div class="space-y-6">
  <!-- Page header -->
  <div class="border-b border-secondary-200 pb-4">
    <h1 class="text-2xl font-bold text-secondary-900">Reports & Analytics</h1>
    <p class="mt-1 text-sm text-secondary-600">
      Generate comprehensive reports and analyze church data.
    </p>
  </div>

  <!-- Report categories -->
  <div class="grid grid-cols-1 gap-6 sm:grid-cols-2 lg:grid-cols-3">
    <!-- Financial Reports -->
    <div class="bg-white overflow-hidden shadow-sm rounded-lg">
      <div class="p-6">
        <div class="flex items-center">
          <div class="flex-shrink-0">
            <div class="w-10 h-10 bg-green-100 rounded-lg flex items-center justify-center">
              <svg class="w-6 h-6 text-green-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8c-1.657 0-3 .895-3 2s1.343 2 3 2 3 .895 3 2-1.343 2-3 2m0-8c1.11 0 2.08.402 2.599 1M12 8V7m0 1v8m0 0v1m0-1c-1.11 0-2.08-.402-2.599-1" />
              </svg>
            </div>
          </div>
          <div class="ml-4">
            <h3 class="text-lg font-medium text-secondary-900">Financial Reports</h3>
            <p class="text-sm text-secondary-500">Donations, tithes, and financial summaries</p>
          </div>
        </div>
        <div class="mt-6">
          <a
            href="/reports/financial"
            class="inline-flex items-center justify-center w-full px-4 py-2 text-base font-medium text-white bg-primary-600 rounded-lg hover:bg-primary-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-primary-500 transition-all duration-200"
          >
            View Financial Reports
          </a>
        </div>
      </div>
    </div>

    <!-- Attendance Reports -->
    <div class="bg-white overflow-hidden shadow-sm rounded-lg">
      <div class="p-6">
        <div class="flex items-center">
          <div class="flex-shrink-0">
            <div class="w-10 h-10 bg-blue-100 rounded-lg flex items-center justify-center">
              <svg class="w-6 h-6 text-blue-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 19v-6a2 2 0 00-2-2H5a2 2 0 00-2 2v6a2 2 0 002 2h2a2 2 0 002-2zm0 0V9a2 2 0 012-2h2a2 2 0 012 2v10m-6 0a2 2 0 002 2h2a2 2 0 002-2m0 0V5a2 2 0 012-2h2a2 2 0 012 2v14a2 2 0 01-2 2h-2a2 2 0 01-2-2z" />
              </svg>
            </div>
          </div>
          <div class="ml-4">
            <h3 class="text-lg font-medium text-secondary-900">Attendance Reports</h3>
            <p class="text-sm text-secondary-500">Event attendance and member engagement</p>
          </div>
        </div>
        <div class="mt-6">
          <a
            href="/reports/attendance"
            class="inline-flex items-center justify-center w-full px-4 py-2 text-base font-medium text-white bg-primary-600 rounded-lg hover:bg-primary-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-primary-500 transition-all duration-200"
          >
            View Attendance Reports
          </a>
        </div>
      </div>
    </div>

    <!-- Member Reports -->
    <div class="bg-white overflow-hidden shadow-sm rounded-lg">
      <div class="p-6">
        <div class="flex items-center">
          <div class="flex-shrink-0">
            <div class="w-10 h-10 bg-purple-100 rounded-lg flex items-center justify-center">
              <svg class="w-6 h-6 text-purple-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M17 20h5v-2a3 3 0 00-5.356-1.857M17 20H7m10 0v-2c0-.656-.126-1.283-.356-1.857M7 20H2v-2a3 3 0 015.356-1.857M7 20v-2c0-.656.126-1.283.356-1.857m0 0a5.002 5.002 0 019.288 0M15 7a3 3 0 11-6 0 3 3 0 016 0zm6 3a2 2 0 11-4 0 2 2 0 014 0zM7 10a2 2 0 11-4 0 2 2 0 014 0z" />
              </svg>
            </div>
          </div>
          <div class="ml-4">
            <h3 class="text-lg font-medium text-secondary-900">Member Reports</h3>
            <p class="text-sm text-secondary-500">Member growth and engagement analytics</p>
          </div>
        </div>
        <div class="mt-6">
          <a
            href="/reports/members"
            class="inline-flex items-center justify-center w-full px-4 py-2 text-base font-medium text-white bg-primary-600 rounded-lg hover:bg-primary-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-primary-500 transition-all duration-200"
          >
            View Member Reports
          </a>
        </div>
      </div>
    </div>

    <!-- Volunteer Reports -->
    <div class="bg-white overflow-hidden shadow-sm rounded-lg">
      <div class="p-6">
        <div class="flex items-center">
          <div class="flex-shrink-0">
            <div class="w-10 h-10 bg-orange-100 rounded-lg flex items-center justify-center">
              <svg class="w-6 h-6 text-orange-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4.318 6.318a4.5 4.5 0 000 6.364L12 20.364l7.682-7.682a4.5 4.5 0 00-6.364-6.364L12 7.636l-1.318-1.318a4.5 4.5 0 00-6.364 0z" />
              </svg>
            </div>
          </div>
          <div class="ml-4">
            <h3 class="text-lg font-medium text-secondary-900">Volunteer Reports</h3>
            <p class="text-sm text-secondary-500">Volunteer hours and participation tracking</p>
          </div>
        </div>
        <div class="mt-6">
          <a
            href="/reports/volunteers"
            class="inline-flex items-center justify-center w-full px-4 py-2 text-base font-medium text-white bg-primary-600 rounded-lg hover:bg-primary-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-primary-500 transition-all duration-200"
          >
            View Volunteer Reports
          </a>
        </div>
      </div>
    </div>

    {#if $user?.role === 'Admin'}
      <!-- Admin Reports -->
      <div class="bg-white overflow-hidden shadow-sm rounded-lg">
        <div class="p-6">
          <div class="flex items-center">
            <div class="flex-shrink-0">
              <div class="w-10 h-10 bg-red-100 rounded-lg flex items-center justify-center">
                <svg class="w-6 h-6 text-red-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12l2 2 4-4m5.618-4.016A11.955 11.955 0 0112 2.944a11.955 11.955 0 01-8.618 3.04A12.02 12.02 0 003 9c0 5.591 3.824 10.29 9 11.622 5.176-1.332 9-6.031 9-11.622 0-1.042-.133-2.052-.382-3.016z" />
                </svg>
              </div>
            </div>
            <div class="ml-4">
              <h3 class="text-lg font-medium text-secondary-900">System Reports</h3>
              <p class="text-sm text-secondary-500">User activity and system analytics</p>
            </div>
          </div>
          <div class="mt-6">
            <a
              href="/reports/system"
              class="inline-flex items-center justify-center w-full px-4 py-2 text-base font-medium text-white bg-primary-600 rounded-lg hover:bg-primary-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-primary-500 transition-all duration-200"
            >
              View System Reports
            </a>
          </div>
        </div>
      </div>
    {/if}

    <!-- Custom Reports -->
    <div class="bg-white overflow-hidden shadow-sm rounded-lg">
      <div class="p-6">
        <div class="flex items-center">
          <div class="flex-shrink-0">
            <div class="w-10 h-10 bg-gray-100 rounded-lg flex items-center justify-center">
              <svg class="w-6 h-6 text-gray-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 6V4m0 2a2 2 0 100 4m0-4a2 2 0 110 4m-6 8a2 2 0 100-4m0 4a2 2 0 100 4m0-4v2m0-6V4m6 6v10m6-2a2 2 0 100-4m0 4a2 2 0 100 4m0-4v2m0-6V4" />
              </svg>
            </div>
          </div>
          <div class="ml-4">
            <h3 class="text-lg font-medium text-secondary-900">Custom Reports</h3>
            <p class="text-sm text-secondary-500">Build custom reports with filters</p>
          </div>
        </div>
        <div class="mt-6">
          <a
            href="/reports/custom"
            class="inline-flex items-center justify-center w-full px-4 py-2 text-base font-medium text-secondary-700 bg-transparent border border-secondary-300 rounded-lg hover:bg-secondary-50 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-secondary-500 transition-all duration-200"
          >
            Create Custom Report
          </a>
        </div>
      </div>
    </div>
  </div>
</div>
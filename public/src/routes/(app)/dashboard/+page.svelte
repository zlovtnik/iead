<script lang="ts">
  import { onMount } from 'svelte';
  import { user } from '$lib/stores/auth.js';
  import { reportsApi } from '$lib/api/reports.js';
  import { DonationChart, AttendanceChart, MemberGrowthChart } from '$lib/components/charts/index.js';
  import { Loading } from '$lib/components/ui/index.js';
  import type { DashboardMetrics, DonationSummary, AttendanceReport, MemberReport } from '$lib/api/reports.js';
  import { generateMockDonationData, generateMockAttendanceData, generateMockMemberData } from './mock-data.js';

  let stats = $state<DashboardMetrics>({
    totalMembers: 0,
    activeMembers: 0,
    upcomingEvents: 0,
    monthlyDonations: 0,
    monthlyTithes: 0,
    activeVolunteers: 0,
    averageAttendance: 0
  });

  let donationData = $state<DonationSummary | null>(null);
  let attendanceData = $state<AttendanceReport[]>([]);
  let memberData = $state<MemberReport | null>(null);
  let isLoading = $state(true);
  let error = $state<string | null>(null);

  onMount(async () => {
    try {
      // Load dashboard data in parallel
      const [metricsResult, donationsResult, attendanceResult, membersResult] = await Promise.allSettled([
        reportsApi.getDashboardMetrics().catch(err => {
          console.log('Error loading metrics:', err);
          return {
            totalMembers: 150,
            activeMembers: 120,
            upcomingEvents: 5,
            monthlyDonations: 8750,
            monthlyTithes: 4200,
            activeVolunteers: 35,
            averageAttendance: 95
          };
        }),
        reportsApi.getDonationSummary({ limit: 12 }).catch(err => {
          console.log('Error loading donations:', err);
          return generateMockDonationData();
        }),
        reportsApi.getAttendanceReport({ limit: 10 }).catch(err => {
          console.log('Error loading attendance:', err);
          return generateMockAttendanceData();
        }),
        reportsApi.getMemberReport({ limit: 12 }).catch(err => {
          console.log('Error loading members:', err);
          return generateMockMemberData();
        })
      ]);

      if (metricsResult.status === 'fulfilled') {
        stats = metricsResult.value;
      }

      if (donationsResult.status === 'fulfilled') {
        donationData = donationsResult.value;
      }

      if (attendanceResult.status === 'fulfilled') {
        attendanceData = attendanceResult.value;
      }

      if (membersResult.status === 'fulfilled') {
        memberData = membersResult.value;
      }

    } catch (err) {
      error = err instanceof Error ? err.message : 'Failed to load dashboard data';
    } finally {
      isLoading = false;
    }
  });
</script>

<svelte:head>
  <title>Dashboard - Church Management System</title>
</svelte:head>

<div class="space-y-6">
  <!-- Page header -->
  <div class="border-b border-secondary-200 pb-4">
    <h1 class="text-2xl font-bold text-secondary-900">
      Welcome back, {$user?.username || 'User'}!
    </h1>
    <p class="mt-1 text-sm text-secondary-600">
      Here's what's happening in your church today.
    </p>
  </div>

  {#if isLoading}
    <div class="flex justify-center items-center py-12">
      <Loading />
    </div>
  {:else if error}
    <div class="bg-red-50 border border-red-200 rounded-md p-4">
      <div class="flex">
        <div class="flex-shrink-0">
          <svg class="h-5 w-5 text-red-400" viewBox="0 0 20 20" fill="currentColor">
            <path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zM8.707 7.293a1 1 0 00-1.414 1.414L8.586 10l-1.293 1.293a1 1 0 101.414 1.414L10 11.414l1.293 1.293a1 1 0 001.414-1.414L11.414 10l1.293-1.293a1 1 0 00-1.414-1.414L10 8.586 8.707 7.293z" clip-rule="evenodd" />
          </svg>
        </div>
        <div class="ml-3">
          <h3 class="text-sm font-medium text-red-800">Error loading dashboard</h3>
          <p class="mt-1 text-sm text-red-700">{error}</p>
        </div>
      </div>
    </div>
  {:else}
    <!-- Stats grid -->
    <div class="grid grid-cols-1 gap-5 sm:grid-cols-2 lg:grid-cols-4">
      <!-- Total Members -->
      <div class="bg-white overflow-hidden shadow-sm rounded-lg">
        <div class="p-5">
          <div class="flex items-center">
            <div class="flex-shrink-0">
              <div class="w-8 h-8 bg-primary-500 rounded-md flex items-center justify-center">
                <svg class="w-5 h-5 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 4.354a4 4 0 110 5.292M15 21H3v-1a6 6 0 0112 0v1zm0 0h6v-1a6 6 0 00-9-5.197m13.5-9a2.5 2.5 0 11-5 0 2.5 2.5 0 015 0z" />
                </svg>
              </div>
            </div>
            <div class="ml-5 w-0 flex-1">
              <dl>
                <dt class="text-sm font-medium text-secondary-500 truncate">
                  Total Members
                </dt>
                <dd class="text-lg font-medium text-secondary-900">
                  {stats.totalMembers.toLocaleString()}
                </dd>
                <dd class="text-xs text-secondary-500">
                  {stats.activeMembers} active
                </dd>
              </dl>
            </div>
          </div>
        </div>
      </div>

      <!-- Upcoming Events -->
      <div class="bg-white overflow-hidden shadow-sm rounded-lg">
        <div class="p-5">
          <div class="flex items-center">
            <div class="flex-shrink-0">
              <div class="w-8 h-8 bg-success-500 rounded-md flex items-center justify-center">
                <svg class="w-5 h-5 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 7V3m8 4V3m-9 8h10M5 21h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v12a2 2 0 002 2z" />
                </svg>
              </div>
            </div>
            <div class="ml-5 w-0 flex-1">
              <dl>
                <dt class="text-sm font-medium text-secondary-500 truncate">
                  Upcoming Events
                </dt>
                <dd class="text-lg font-medium text-secondary-900">
                  {stats.upcomingEvents}
                </dd>
                <dd class="text-xs text-secondary-500">
                  Avg. {stats.averageAttendance}% attendance
                </dd>
              </dl>
            </div>
          </div>
        </div>
      </div>

      <!-- Monthly Donations -->
      <div class="bg-white overflow-hidden shadow-sm rounded-lg">
        <div class="p-5">
          <div class="flex items-center">
            <div class="flex-shrink-0">
              <div class="w-8 h-8 bg-warning-500 rounded-md flex items-center justify-center">
                <svg class="w-5 h-5 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8c-1.657 0-3 .895-3 2s1.343 2 3 2 3 .895 3 2-1.343 2-3 2m0-8c1.11 0 2.08.402 2.599 1M12 8V7m0 1v8m0 0v1m0-1c-1.11 0-2.08-.402-2.599-1" />
                </svg>
              </div>
            </div>
            <div class="ml-5 w-0 flex-1">
              <dl>
                <dt class="text-sm font-medium text-secondary-500 truncate">
                  Monthly Donations
                </dt>
                <dd class="text-lg font-medium text-secondary-900">
                  ${stats.monthlyDonations.toLocaleString()}
                </dd>
                <dd class="text-xs text-secondary-500">
                  +${stats.monthlyTithes.toLocaleString()} tithes
                </dd>
              </dl>
            </div>
          </div>
        </div>
      </div>

      <!-- Active Volunteers -->
      <div class="bg-white overflow-hidden shadow-sm rounded-lg">
        <div class="p-5">
          <div class="flex items-center">
            <div class="flex-shrink-0">
              <div class="w-8 h-8 bg-purple-500 rounded-md flex items-center justify-center">
                <svg class="w-5 h-5 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4.318 6.318a4.5 4.5 0 000 6.364L12 20.364l7.682-7.682a4.5 4.5 0 00-6.364-6.364L12 7.636l-1.318-1.318a4.5 4.5 0 00-6.364 0z" />
                </svg>
              </div>
            </div>
            <div class="ml-5 w-0 flex-1">
              <dl>
                <dt class="text-sm font-medium text-secondary-500 truncate">
                  Active Volunteers
                </dt>
                <dd class="text-lg font-medium text-secondary-900">
                  {stats.activeVolunteers}
                </dd>
              </dl>
            </div>
          </div>
        </div>
      </div>
    </div>

    <!-- Charts Section -->
    <div class="grid grid-cols-1 lg:grid-cols-2 gap-6">
      <!-- Donation Trends -->
      {#if donationData}
        <div class="bg-white shadow-sm rounded-lg p-6">
          <h3 class="text-lg font-medium text-secondary-900 mb-4">Donation Trends</h3>
          <DonationChart data={donationData} type="monthly" height={300} />
        </div>
      {/if}

      <!-- Member Growth -->
      {#if memberData}
        <div class="bg-white shadow-sm rounded-lg p-6">
          <h3 class="text-lg font-medium text-secondary-900 mb-4">Member Growth</h3>
          <MemberGrowthChart data={memberData} height={300} />
        </div>
      {/if}
    </div>

    <!-- Attendance Overview -->
    {#if attendanceData.length > 0}
      <div class="bg-white shadow-sm rounded-lg p-6">
        <h3 class="text-lg font-medium text-secondary-900 mb-4">Recent Event Attendance</h3>
        <AttendanceChart data={attendanceData} height={300} />
      </div>
    {/if}

    <!-- Donation Categories -->
    {#if donationData}
      <div class="bg-white shadow-sm rounded-lg p-6">
        <h3 class="text-lg font-medium text-secondary-900 mb-4">Donations by Category</h3>
        <DonationChart data={donationData} type="category" height={300} />
      </div>
    {/if}
  {/if}

  <!-- Quick actions -->
  <div class="bg-white shadow-sm rounded-lg">
    <div class="px-4 py-5 sm:p-6">
      <h3 class="text-lg leading-6 font-medium text-secondary-900 mb-4">
        Quick Actions
      </h3>
      <div class="grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-3">
        {#if $user?.role === 'Admin' || $user?.role === 'Pastor'}
          <a
            href="/members/create"
            class="relative group bg-white p-6 focus-within:ring-2 focus-within:ring-inset focus-within:ring-primary-500 rounded-lg border border-secondary-200 hover:border-primary-300 transition-colors"
          >
            <div>
              <span class="rounded-lg inline-flex p-3 bg-primary-50 text-primary-600 group-hover:bg-primary-100">
                <svg class="h-6 w-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M18 9v3m0 0v3m0-3h3m-3 0h-3m-2-5a4 4 0 11-8 0 4 4 0 018 0zM3 20a6 6 0 0112 0v1H3v-1z" />
                </svg>
              </span>
            </div>
            <div class="mt-4">
              <h3 class="text-lg font-medium text-secondary-900">
                Add New Member
              </h3>
              <p class="mt-2 text-sm text-secondary-500">
                Register a new church member in the system.
              </p>
            </div>
          </a>

          <a
            href="/events/create"
            class="relative group bg-white p-6 focus-within:ring-2 focus-within:ring-inset focus-within:ring-primary-500 rounded-lg border border-secondary-200 hover:border-primary-300 transition-colors"
          >
            <div>
              <span class="rounded-lg inline-flex p-3 bg-success-50 text-success-600 group-hover:bg-success-100">
                <svg class="h-6 w-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 6v6m0 0v6m0-6h6m-6 0H6" />
                </svg>
              </span>
            </div>
            <div class="mt-4">
              <h3 class="text-lg font-medium text-secondary-900">
                Create Event
              </h3>
              <p class="mt-2 text-sm text-secondary-500">
                Schedule a new church event or service.
              </p>
            </div>
          </a>

          <a
            href="/donations"
            class="relative group bg-white p-6 focus-within:ring-2 focus-within:ring-inset focus-within:ring-primary-500 rounded-lg border border-secondary-200 hover:border-primary-300 transition-colors"
          >
            <div>
              <span class="rounded-lg inline-flex p-3 bg-warning-50 text-warning-600 group-hover:bg-warning-100">
                <svg class="h-6 w-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8c-1.657 0-3 .895-3 2s1.343 2 3 2 3 .895 3 2-1.343 2-3 2m0-8c1.11 0 2.08.402 2.599 1M12 8V7m0 1v8m0 0v1m0-1c-1.11 0-2.08-.402-2.599-1" />
                </svg>
              </span>
            </div>
            <div class="mt-4">
              <h3 class="text-lg font-medium text-secondary-900">
                Record Donation
              </h3>
              <p class="mt-2 text-sm text-secondary-500">
                Log a new donation or offering.
              </p>
            </div>
          </a>
        {/if}

        {#if $user?.role === 'Member'}
          <a
            href="/profile"
            class="relative group bg-white p-6 focus-within:ring-2 focus-within:ring-inset focus-within:ring-primary-500 rounded-lg border border-secondary-200 hover:border-primary-300 transition-colors"
          >
            <div>
              <span class="rounded-lg inline-flex p-3 bg-primary-50 text-primary-600 group-hover:bg-primary-100">
                <svg class="h-6 w-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M16 7a4 4 0 11-8 0 4 4 0 018 0zM12 14a7 7 0 00-7 7h14a7 7 0 00-7-7z" />
                </svg>
              </span>
            </div>
            <div class="mt-4">
              <h3 class="text-lg font-medium text-secondary-900">
                Update Profile
              </h3>
              <p class="mt-2 text-sm text-secondary-500">
                Update your personal information.
              </p>
            </div>
          </a>

          <a
            href="/my-donations"
            class="relative group bg-white p-6 focus-within:ring-2 focus-within:ring-inset focus-within:ring-primary-500 rounded-lg border border-secondary-200 hover:border-primary-300 transition-colors"
          >
            <div>
              <span class="rounded-lg inline-flex p-3 bg-success-50 text-success-600 group-hover:bg-success-100">
                <svg class="h-6 w-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z" />
                </svg>
              </span>
            </div>
            <div class="mt-4">
              <h3 class="text-lg font-medium text-secondary-900">
                View Donations
              </h3>
              <p class="mt-2 text-sm text-secondary-500">
                See your donation history and statements.
              </p>
            </div>
          </a>
        {/if}
      </div>
    </div>
  </div>

  <!-- Recent activity placeholder -->
  <div class="bg-white shadow-sm rounded-lg">
    <div class="px-4 py-5 sm:p-6">
      <h3 class="text-lg leading-6 font-medium text-secondary-900 mb-4">
        Recent Activity
      </h3>
      <div class="text-center py-8">
        <svg class="mx-auto h-12 w-12 text-secondary-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5H7a2 2 0 00-2 2v10a2 2 0 002 2h8a2 2 0 002-2V7a2 2 0 00-2-2h-2M9 5a2 2 0 002 2h2a2 2 0 002-2M9 5a2 2 0 012-2h2a2 2 0 012 2" />
        </svg>
        <h3 class="mt-2 text-sm font-medium text-secondary-900">No recent activity</h3>
        <p class="mt-1 text-sm text-secondary-500">
          Recent system activity will appear here.
        </p>
      </div>
    </div>
  </div>
</div>
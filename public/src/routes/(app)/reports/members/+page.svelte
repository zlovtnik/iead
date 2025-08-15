<script lang="ts">
  import { onMount } from 'svelte';
  import { reportsApi } from '$lib/api/reports.js';
  import { MemberGrowthChart } from '$lib/components/charts/index.js';
  import { Button, Input, Loading, DataTable } from '$lib/components/ui/index.js';
  import type { MemberReport, ReportFilters } from '$lib/api/reports.js';

  let memberData = $state<MemberReport | null>(null);
  let isLoading = $state(true);
  let error = $state<string | null>(null);
  let isExporting = $state(false);

  // Filter state
  let filters = $state<ReportFilters>({
    startDate: new Date(new Date().getFullYear(), 0, 1).toISOString().split('T')[0], // Start of year
    endDate: new Date().toISOString().split('T')[0] // Today
  });

  async function loadMemberData() {
    try {
      isLoading = true;
      error = null;
      memberData = await reportsApi.getMemberReport(filters);
    } catch (err) {
      error = err instanceof Error ? err.message : 'Failed to load member data';
    } finally {
      isLoading = false;
    }
  }

  async function exportReport(format: 'pdf' | 'csv') {
    try {
      isExporting = true;
      const blob = await reportsApi.exportReport('members', format, filters);
      
      // Create download link
      const url = window.URL.createObjectURL(blob);
      const a = document.createElement('a');
      a.style.display = 'none';
      a.href = url;
      a.download = `member-report-${new Date().toISOString().split('T')[0]}.${format}`;
      document.body.appendChild(a);
      a.click();
      window.URL.revokeObjectURL(url);
      document.body.removeChild(a);
    } catch (err) {
      error = err instanceof Error ? err.message : 'Failed to export report';
    } finally {
      isExporting = false;
    }
  }

  onMount(() => {
    loadMemberData();
  });

  // Member engagement table columns
  const engagementColumns = [
    { key: 'memberName', label: 'Member Name' },
    { 
      key: 'attendanceRate', 
      label: 'Attendance Rate', 
      format: (value: number) => `${value.toFixed(1)}%` 
    },
    { 
      key: 'donationTotal', 
      label: 'Total Donations', 
      format: (value: number) => `$${value.toLocaleString()}` 
    },
    { key: 'volunteerHours', label: 'Volunteer Hours' },
    { 
      key: 'engagementScore', 
      label: 'Engagement Score', 
      format: (value: number) => value.toFixed(1) 
    }
  ];
</script>

<svelte:head>
  <title>Member Reports - Church Management System</title>
</svelte:head>

<div class="space-y-6">
  <!-- Page header -->
  <div class="border-b border-secondary-200 pb-4">
    <div class="flex justify-between items-center">
      <div>
        <h1 class="text-2xl font-bold text-secondary-900">Member Reports</h1>
        <p class="mt-1 text-sm text-secondary-600">
          Track member growth and engagement analytics.
        </p>
      </div>
      <div class="flex space-x-2">
        <Button 
          onclick={() => exportReport('csv')} 
          variant="secondary" 
          disabled={isExporting || !memberData}
        >
          {isExporting ? 'Exporting...' : 'Export CSV'}
        </Button>
        <Button 
          onclick={() => exportReport('pdf')} 
          variant="primary" 
          disabled={isExporting || !memberData}
        >
          {isExporting ? 'Exporting...' : 'Export PDF'}
        </Button>
      </div>
    </div>
  </div>

  <!-- Filters -->
  <div class="bg-white shadow-sm rounded-lg p-6">
    <h3 class="text-lg font-medium text-secondary-900 mb-4">Report Filters</h3>
    <div class="grid grid-cols-1 gap-4 sm:grid-cols-3">
      <div>
        <label for="startDate" class="block text-sm font-medium text-secondary-700 mb-1">
          Start Date
        </label>
        <Input
          id="startDate"
          type="date"
          bind:value={filters.startDate}
          onchange={loadMemberData}
        />
      </div>
      <div>
        <label for="endDate" class="block text-sm font-medium text-secondary-700 mb-1">
          End Date
        </label>
        <Input
          id="endDate"
          type="date"
          bind:value={filters.endDate}
          onchange={loadMemberData}
        />
      </div>
      <div class="flex items-end">
        <Button onclick={loadMemberData} variant="primary" class="w-full">
          Update Report
        </Button>
      </div>
    </div>
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
          <h3 class="text-sm font-medium text-red-800">Error loading member data</h3>
          <p class="mt-1 text-sm text-red-700">{error}</p>
        </div>
      </div>
    </div>
  {:else if memberData}
    <!-- Summary Cards -->
    <div class="grid grid-cols-1 gap-5 sm:grid-cols-2 lg:grid-cols-3">
      <div class="bg-white overflow-hidden shadow-sm rounded-lg">
        <div class="p-5">
          <div class="flex items-center">
            <div class="flex-shrink-0">
              <div class="w-8 h-8 bg-blue-500 rounded-md flex items-center justify-center">
                <svg class="w-5 h-5 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M17 20h5v-2a3 3 0 00-5.356-1.857M17 20H7m10 0v-2c0-.656-.126-1.283-.356-1.857M7 20H2v-2a3 3 0 015.356-1.857M7 20v-2c0-.656.126-1.283.356-1.857m0 0a5.002 5.002 0 019.288 0M15 7a3 3 0 11-6 0 3 3 0 016 0zm6 3a2 2 0 11-4 0 2 2 0 014 0zM7 10a2 2 0 11-4 0 2 2 0 014 0z" />
                </svg>
              </div>
            </div>
            <div class="ml-5 w-0 flex-1">
              <dl>
                <dt class="text-sm font-medium text-secondary-500 truncate">Total Members</dt>
                <dd class="text-lg font-medium text-secondary-900">
                  {memberData.totalMembers.toLocaleString()}
                </dd>
              </dl>
            </div>
          </div>
        </div>
      </div>

      <div class="bg-white overflow-hidden shadow-sm rounded-lg">
        <div class="p-5">
          <div class="flex items-center">
            <div class="flex-shrink-0">
              <div class="w-8 h-8 bg-green-500 rounded-md flex items-center justify-center">
                <svg class="w-5 h-5 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M18 9v3m0 0v3m0-3h3m-3 0h-3m-2-5a4 4 0 11-8 0 4 4 0 018 0zM3 20a6 6 0 0112 0v1H3v-1z" />
                </svg>
              </div>
            </div>
            <div class="ml-5 w-0 flex-1">
              <dl>
                <dt class="text-sm font-medium text-secondary-500 truncate">New This Month</dt>
                <dd class="text-lg font-medium text-secondary-900">
                  {memberData.newMembersThisMonth}
                </dd>
              </dl>
            </div>
          </div>
        </div>
      </div>

      <div class="bg-white overflow-hidden shadow-sm rounded-lg">
        <div class="p-5">
          <div class="flex items-center">
            <div class="flex-shrink-0">
              <div class="w-8 h-8 bg-purple-500 rounded-md flex items-center justify-center">
                <svg class="w-5 h-5 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13 7h8m0 0v8m0-8l-8 8-4-4-6 6" />
                </svg>
              </div>
            </div>
            <div class="ml-5 w-0 flex-1">
              <dl>
                <dt class="text-sm font-medium text-secondary-500 truncate">Growth Rate</dt>
                <dd class="text-lg font-medium text-secondary-900">
                  {memberData.totalMembers > 0 
                    ? ((memberData.newMembersThisMonth / memberData.totalMembers) * 100).toFixed(1)
                    : 0}%
                </dd>
              </dl>
            </div>
          </div>
        </div>
      </div>
    </div>

    <!-- Member Growth Chart -->
    <div class="bg-white shadow-sm rounded-lg p-6">
      <h3 class="text-lg font-medium text-secondary-900 mb-4">Member Growth Over Time</h3>
      <MemberGrowthChart data={memberData} height={400} />
    </div>

    <!-- Member Engagement Table -->
    <div class="bg-white shadow-sm rounded-lg">
      <div class="px-4 py-5 sm:p-6">
        <h3 class="text-lg leading-6 font-medium text-secondary-900 mb-4">Member Engagement Analysis</h3>
        <p class="text-sm text-secondary-600 mb-4">
          Engagement score is calculated based on attendance rate, donation activity, and volunteer participation.
        </p>
        <DataTable
          data={memberData.memberEngagement}
          columns={engagementColumns}
          searchable={true}
          sortable={true}
        />
      </div>
    </div>

    <!-- Monthly Growth Summary -->
    <div class="bg-white shadow-sm rounded-lg">
      <div class="px-4 py-5 sm:p-6">
        <h3 class="text-lg leading-6 font-medium text-secondary-900 mb-4">Monthly Growth Summary</h3>
        <div class="overflow-x-auto">
          <table class="min-w-full divide-y divide-secondary-200">
            <thead class="bg-secondary-50">
              <tr>
                <th class="px-6 py-3 text-left text-xs font-medium text-secondary-500 uppercase tracking-wider">
                  Month
                </th>
                <th class="px-6 py-3 text-left text-xs font-medium text-secondary-500 uppercase tracking-wider">
                  New Members
                </th>
              </tr>
            </thead>
            <tbody class="bg-white divide-y divide-secondary-200">
              {#each memberData.membersByJoinDate as monthData}
                <tr>
                  <td class="px-6 py-4 whitespace-nowrap text-sm font-medium text-secondary-900">
                    {monthData.month}
                  </td>
                  <td class="px-6 py-4 whitespace-nowrap text-sm text-secondary-500">
                    {monthData.count}
                  </td>
                </tr>
              {/each}
            </tbody>
          </table>
        </div>
      </div>
    </div>
  {/if}
</div>
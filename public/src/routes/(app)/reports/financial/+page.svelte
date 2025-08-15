<script lang="ts">
  import { onMount } from 'svelte';
  import { reportsApi } from '$lib/api/reports.js';
  import { DonationChart } from '$lib/components/charts/index.js';
  import { Button, Input, Loading, DataTable } from '$lib/components/ui/index.js';
  import type { FinancialReport, ReportFilters } from '$lib/api/reports.js';

  let financialData = $state<FinancialReport | null>(null);
  let isLoading = $state(true);
  let error = $state<string | null>(null);
  let isExporting = $state(false);

  // Filter state
  let filters = $state<ReportFilters>({
    startDate: new Date(new Date().getFullYear(), 0, 1).toISOString().split('T')[0], // Start of year
    endDate: new Date().toISOString().split('T')[0] // Today
  });

  async function loadFinancialData() {
    try {
      isLoading = true;
      error = null;
      financialData = await reportsApi.getFinancialReport(filters);
    } catch (err) {
      error = err instanceof Error ? err.message : 'Failed to load financial data';
    } finally {
      isLoading = false;
    }
  }

  async function exportReport(format: 'pdf' | 'csv') {
    try {
      isExporting = true;
      const blob = await reportsApi.exportReport('financial', format, filters);
      
      // Create download link
      const url = window.URL.createObjectURL(blob);
      const a = document.createElement('a');
      a.style.display = 'none';
      a.href = url;
      a.download = `financial-report-${new Date().toISOString().split('T')[0]}.${format}`;
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
    loadFinancialData();
  });

  // Top donors table columns
  const topDonorsColumns = [
    { key: 'memberName', label: 'Member Name' },
    { key: 'totalAmount', label: 'Total Amount', format: (value: number) => `$${value.toLocaleString()}` },
    { key: 'donationCount', label: 'Donations' }
  ];

  // Monthly tithes table columns
  const monthlyTithesColumns = [
    { key: 'month', label: 'Month' },
    { key: 'year', label: 'Year' },
    { key: 'totalAmount', label: 'Total Amount', format: (value: number) => `$${value.toLocaleString()}` },
    { key: 'paidAmount', label: 'Paid Amount', format: (value: number) => `$${value.toLocaleString()}` },
    { key: 'unpaidAmount', label: 'Unpaid Amount', format: (value: number) => `$${value.toLocaleString()}` }
  ];
</script>

<svelte:head>
  <title>Financial Reports - Church Management System</title>
</svelte:head>

<div class="space-y-6">
  <!-- Page header -->
  <div class="border-b border-secondary-200 pb-4">
    <div class="flex justify-between items-center">
      <div>
        <h1 class="text-2xl font-bold text-secondary-900">Financial Reports</h1>
        <p class="mt-1 text-sm text-secondary-600">
          Comprehensive financial analytics and donation tracking.
        </p>
      </div>
      <div class="flex space-x-2">
        <Button 
          onclick={() => exportReport('csv')} 
          variant="secondary" 
          disabled={isExporting || !financialData}
        >
          {isExporting ? 'Exporting...' : 'Export CSV'}
        </Button>
        <Button 
          onclick={() => exportReport('pdf')} 
          variant="primary" 
          disabled={isExporting || !financialData}
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
          onchange={loadFinancialData}
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
          onchange={loadFinancialData}
        />
      </div>
      <div class="flex items-end">
        <Button onclick={loadFinancialData} variant="primary" class="w-full">
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
          <h3 class="text-sm font-medium text-red-800">Error loading financial data</h3>
          <p class="mt-1 text-sm text-red-700">{error}</p>
        </div>
      </div>
    </div>
  {:else if financialData}
    <!-- Summary Cards -->
    <div class="grid grid-cols-1 gap-5 sm:grid-cols-2 lg:grid-cols-4">
      <div class="bg-white overflow-hidden shadow-sm rounded-lg">
        <div class="p-5">
          <div class="flex items-center">
            <div class="flex-shrink-0">
              <div class="w-8 h-8 bg-green-500 rounded-md flex items-center justify-center">
                <svg class="w-5 h-5 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8c-1.657 0-3 .895-3 2s1.343 2 3 2 3 .895 3 2-1.343 2-3 2m0-8c1.11 0 2.08.402 2.599 1M12 8V7m0 1v8m0 0v1m0-1c-1.11 0-2.08-.402-2.599-1" />
                </svg>
              </div>
            </div>
            <div class="ml-5 w-0 flex-1">
              <dl>
                <dt class="text-sm font-medium text-secondary-500 truncate">Total Donations</dt>
                <dd class="text-lg font-medium text-secondary-900">
                  ${financialData.donations.totalDonations.toLocaleString()}
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
              <div class="w-8 h-8 bg-blue-500 rounded-md flex items-center justify-center">
                <svg class="w-5 h-5 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 7h6m0 10v-3m-3 3h.01M9 17h.01M9 14h.01M12 14h.01M15 11h.01M12 11h.01M9 11h.01M7 21h10a2 2 0 002-2V5a2 2 0 00-2-2H7a2 2 0 00-2 2v14a2 2 0 002 2z" />
                </svg>
              </div>
            </div>
            <div class="ml-5 w-0 flex-1">
              <dl>
                <dt class="text-sm font-medium text-secondary-500 truncate">Total Tithes</dt>
                <dd class="text-lg font-medium text-secondary-900">
                  ${financialData.tithes.totalTithes.toLocaleString()}
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
                <dt class="text-sm font-medium text-secondary-500 truncate">Total Income</dt>
                <dd class="text-lg font-medium text-secondary-900">
                  ${financialData.summary.totalIncome.toLocaleString()}
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
              <div class="w-8 h-8 bg-orange-500 rounded-md flex items-center justify-center">
                <svg class="w-5 h-5 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 19v-6a2 2 0 00-2-2H5a2 2 0 00-2 2v6a2 2 0 002 2h2a2 2 0 002-2zm0 0V9a2 2 0 012-2h2a2 2 0 012 2v10m-6 0a2 2 0 002 2h2a2 2 0 002-2m0 0V5a2 2 0 012-2h2a2 2 0 012 2v14a2 2 0 01-2 2h-2a2 2 0 01-2-2z" />
                </svg>
              </div>
            </div>
            <div class="ml-5 w-0 flex-1">
              <dl>
                <dt class="text-sm font-medium text-secondary-500 truncate">Monthly Average</dt>
                <dd class="text-lg font-medium text-secondary-900">
                  ${financialData.summary.monthlyAverage.toLocaleString()}
                </dd>
              </dl>
            </div>
          </div>
        </div>
      </div>
    </div>

    <!-- Charts -->
    <div class="grid grid-cols-1 lg:grid-cols-2 gap-6">
      <!-- Donation Trends -->
      <div class="bg-white shadow-sm rounded-lg p-6">
        <h3 class="text-lg font-medium text-secondary-900 mb-4">Monthly Donation Trends</h3>
        <DonationChart data={financialData.donations} type="monthly" height={300} />
      </div>

      <!-- Donations by Category -->
      <div class="bg-white shadow-sm rounded-lg p-6">
        <h3 class="text-lg font-medium text-secondary-900 mb-4">Donations by Category</h3>
        <DonationChart data={financialData.donations} type="category" height={300} />
      </div>
    </div>

    <!-- Top Donors Table -->
    <div class="bg-white shadow-sm rounded-lg">
      <div class="px-4 py-5 sm:p-6">
        <h3 class="text-lg leading-6 font-medium text-secondary-900 mb-4">Top Donors</h3>
        <DataTable
          data={financialData.donations.topDonors}
          columns={topDonorsColumns}
          searchable={true}
          sortable={true}
        />
      </div>
    </div>

    <!-- Monthly Tithes Table -->
    <div class="bg-white shadow-sm rounded-lg">
      <div class="px-4 py-5 sm:p-6">
        <h3 class="text-lg leading-6 font-medium text-secondary-900 mb-4">Monthly Tithes Summary</h3>
        <DataTable
          data={financialData.tithes.tithesByMonth}
          columns={monthlyTithesColumns}
          searchable={false}
          sortable={true}
        />
      </div>
    </div>
  {/if}
</div>
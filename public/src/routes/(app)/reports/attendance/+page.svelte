<script lang="ts">
  import { onMount } from 'svelte';
  import { reportsApi } from '$lib/api/reports.js';
  import { AttendanceChart } from '$lib/components/charts/index.js';
  import { Button, Input, Loading, DataTable } from '$lib/components/ui/index.js';
  import type { AttendanceReport, ReportFilters } from '$lib/api/reports.js';

  let attendanceData = $state<AttendanceReport[]>([]);
  let isLoading = $state(true);
  let error = $state<string | null>(null);
  let isExporting = $state(false);

  // Filter state
  let filters = $state<ReportFilters>({
    startDate: new Date(new Date().getFullYear(), new Date().getMonth() - 3, 1).toISOString().split('T')[0], // 3 months ago
    endDate: new Date().toISOString().split('T')[0] // Today
  });

  async function loadAttendanceData() {
    try {
      isLoading = true;
      error = null;
      attendanceData = await reportsApi.getAttendanceReport(filters);
    } catch (err) {
      error = err instanceof Error ? err.message : 'Failed to load attendance data';
    } finally {
      isLoading = false;
    }
  }

  async function exportReport(format: 'pdf' | 'csv') {
    try {
      isExporting = true;
      const blob = await reportsApi.exportReport('attendance', format, filters);
      
      // Create download link
      const url = window.URL.createObjectURL(blob);
      const a = document.createElement('a');
      a.style.display = 'none';
      a.href = url;
      a.download = `attendance-report-${new Date().toISOString().split('T')[0]}.${format}`;
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
    loadAttendanceData();
  });

  // Event summary table columns
  const eventColumns = [
    { key: 'eventTitle', label: 'Event' },
    { 
      key: 'eventDate', 
      label: 'Date', 
      format: (value: string) => new Date(value).toLocaleDateString() 
    },
    { key: 'totalAttendees', label: 'Attendees' },
    { 
      key: 'attendanceRate', 
      label: 'Attendance Rate', 
      format: (value: number) => `${value.toFixed(1)}%` 
    }
  ];

  // Calculate summary statistics
  const summaryStats = $derived.by(() => {
    if (attendanceData.length === 0) {
      return {
        totalEvents: 0,
        averageAttendance: 0,
        highestAttendance: 0,
        lowestAttendance: 0,
        averageAttendanceRate: 0
      };
    }

    const totalAttendees = attendanceData.reduce((sum, event) => sum + event.totalAttendees, 0);
    const totalRate = attendanceData.reduce((sum, event) => sum + event.attendanceRate, 0);
    const attendeeCounts = attendanceData.map(event => event.totalAttendees);

    return {
      totalEvents: attendanceData.length,
      averageAttendance: Math.round(totalAttendees / attendanceData.length),
      highestAttendance: Math.max(...attendeeCounts),
      lowestAttendance: Math.min(...attendeeCounts),
      averageAttendanceRate: totalRate / attendanceData.length
    };
  });
</script>

<svelte:head>
  <title>Attendance Reports - Church Management System</title>
</svelte:head>

<div class="space-y-6">
  <!-- Page header -->
  <div class="border-b border-secondary-200 pb-4">
    <div class="flex justify-between items-center">
      <div>
        <h1 class="text-2xl font-bold text-secondary-900">Attendance Reports</h1>
        <p class="mt-1 text-sm text-secondary-600">
          Track event attendance and member engagement patterns.
        </p>
      </div>
      <div class="flex space-x-2">
        <Button 
          onclick={() => exportReport('csv')} 
          variant="secondary" 
          disabled={isExporting || attendanceData.length === 0}
        >
          {isExporting ? 'Exporting...' : 'Export CSV'}
        </Button>
        <Button 
          onclick={() => exportReport('pdf')} 
          variant="primary" 
          disabled={isExporting || attendanceData.length === 0}
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
          onchange={loadAttendanceData}
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
          onchange={loadAttendanceData}
        />
      </div>
      <div class="flex items-end">
        <Button onclick={loadAttendanceData} variant="primary" class="w-full">
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
          <h3 class="text-sm font-medium text-red-800">Error loading attendance data</h3>
          <p class="mt-1 text-sm text-red-700">{error}</p>
        </div>
      </div>
    </div>
  {:else if attendanceData.length === 0}
    <div class="text-center py-12">
      <svg class="mx-auto h-12 w-12 text-secondary-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5H7a2 2 0 00-2 2v10a2 2 0 002 2h8a2 2 0 002-2V7a2 2 0 00-2-2h-2M9 5a2 2 0 002 2h2a2 2 0 002-2M9 5a2 2 0 012-2h2a2 2 0 012 2" />
      </svg>
      <h3 class="mt-2 text-sm font-medium text-secondary-900">No attendance data</h3>
      <p class="mt-1 text-sm text-secondary-500">
        No events found for the selected date range.
      </p>
    </div>
  {:else}
    <!-- Summary Cards -->
    <div class="grid grid-cols-1 gap-5 sm:grid-cols-2 lg:grid-cols-4">
      <div class="bg-white overflow-hidden shadow-sm rounded-lg">
        <div class="p-5">
          <div class="flex items-center">
            <div class="flex-shrink-0">
              <div class="w-8 h-8 bg-blue-500 rounded-md flex items-center justify-center">
                <svg class="w-5 h-5 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 7V3m8 4V3m-9 8h10M5 21h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v12a2 2 0 002 2z" />
                </svg>
              </div>
            </div>
            <div class="ml-5 w-0 flex-1">
              <dl>
                <dt class="text-sm font-medium text-secondary-500 truncate">Total Events</dt>
                <dd class="text-lg font-medium text-secondary-900">
                  {summaryStats.totalEvents}
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
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M17 20h5v-2a3 3 0 00-5.356-1.857M17 20H7m10 0v-2c0-.656-.126-1.283-.356-1.857M7 20H2v-2a3 3 0 015.356-1.857M7 20v-2c0-.656.126-1.283.356-1.857m0 0a5.002 5.002 0 019.288 0M15 7a3 3 0 11-6 0 3 3 0 016 0zm6 3a2 2 0 11-4 0 2 2 0 014 0zM7 10a2 2 0 11-4 0 2 2 0 014 0z" />
                </svg>
              </div>
            </div>
            <div class="ml-5 w-0 flex-1">
              <dl>
                <dt class="text-sm font-medium text-secondary-500 truncate">Average Attendance</dt>
                <dd class="text-lg font-medium text-secondary-900">
                  {summaryStats.averageAttendance}
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
                <dt class="text-sm font-medium text-secondary-500 truncate">Highest Attendance</dt>
                <dd class="text-lg font-medium text-secondary-900">
                  {summaryStats.highestAttendance}
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
                <dt class="text-sm font-medium text-secondary-500 truncate">Avg. Rate</dt>
                <dd class="text-lg font-medium text-secondary-900">
                  {summaryStats.averageAttendanceRate.toFixed(1)}%
                </dd>
              </dl>
            </div>
          </div>
        </div>
      </div>
    </div>

    <!-- Attendance Chart -->
    <div class="bg-white shadow-sm rounded-lg p-6">
      <h3 class="text-lg font-medium text-secondary-900 mb-4">Event Attendance Overview</h3>
      <AttendanceChart data={attendanceData} height={400} />
    </div>

    <!-- Event Summary Table -->
    <div class="bg-white shadow-sm rounded-lg">
      <div class="px-4 py-5 sm:p-6">
        <h3 class="text-lg leading-6 font-medium text-secondary-900 mb-4">Event Summary</h3>
        <DataTable
          data={attendanceData}
          columns={eventColumns}
          searchable={true}
          sortable={true}
        />
      </div>
    </div>
  {/if}
</div>
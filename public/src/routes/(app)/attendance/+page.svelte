<script lang="ts">
  import { onMount, onDestroy } from 'svelte';
  import { page } from '$app/stores';
  import { goto } from '$app/navigation';
  import Button from '$lib/components/ui/Button.svelte';
  import DataTable from '$lib/components/ui/DataTable.svelte';
  import Input from '$lib/components/ui/Input.svelte';
  import Modal from '$lib/components/ui/Modal.svelte';
  import Loading from '$lib/components/ui/Loading.svelte';
  import Toast from '$lib/components/ui/Toast.svelte';
  import {
    attendanceStore,
    attendanceRecords,
    isLoadingAttendance,
    attendanceError,
    selectedAttendanceRecords,
    hasSelectedRecords,
    attendancePagination,
    attendanceActions,
    startAutoRefresh,
    stopAutoRefresh
  } from '$lib/stores/attendance.js';
  import { user } from '$lib/stores/auth.js';
  import { toastStore } from '$lib/stores/ui.js';
  import type { AttendanceRecord, AttendanceSearchParams, AttendanceFilters } from '$lib/api/attendance.js';
  import { hasPermission } from '$lib/utils/permissions.js';

  // Search and filter state
  let searchQuery = '';
  let filters: AttendanceFilters = {
    startDate: '',
    endDate: '',
    event_ids: [],
    member_ids: []
  };
  let hasNotesFilter: boolean | undefined = undefined;
  let showFilters = false;
  let showBulkActions = false;
  let showDeleteConfirm = false;
  let recordToDelete: AttendanceRecord | null = null;
  let showExportModal = false;
  let exportFormat: 'csv' | 'xlsx' = 'csv';

  // Permissions
  $: canManageAttendance = $user ? hasPermission($user, 'manage_attendance') : false;
  $: canViewAttendance = $user ? hasPermission($user, 'view_attendance') : false;
  $: canExportData = $user ? hasPermission($user, 'export_data') : false;

  // Table configuration
  const columns = [
    { key: 'attendance_date', label: 'Date', sortable: true },
    { key: 'member.name', label: 'Member', sortable: true },
    { key: 'event.title', label: 'Event', sortable: true },
    { key: 'event.location', label: 'Location', sortable: false },
    { key: 'notes', label: 'Notes', sortable: false },
    { key: 'actions', label: 'Actions', sortable: false }
  ];

  // Load data on mount
  onMount(async () => {
    if (!canViewAttendance) {
      goto('/unauthorized');
      return;
    }

    await loadAttendanceRecords();
    startAutoRefresh(30000); // Refresh every 30 seconds
  });

  onDestroy(() => {
    stopAutoRefresh();
  });

  // Load attendance records
  async function loadAttendanceRecords() {
    const searchParams: AttendanceSearchParams & AttendanceFilters = {
      query: searchQuery || undefined,
      ...filters,
      hasNotes: hasNotesFilter,
      page: $page.url.searchParams.get('page') ? parseInt($page.url.searchParams.get('page')!) : 1,
      limit: 10,
      sortBy: ($page.url.searchParams.get('sort') as any) || 'attendance_date',
      sortOrder: ($page.url.searchParams.get('order') as any) || 'desc'
    };

    await attendanceActions.loadAttendanceRecords(searchParams);
  }

  // Search handler
  async function handleSearch() {
    await attendanceActions.searchAttendanceRecords({
      query: searchQuery || undefined,
      ...filters,
      hasNotes: hasNotesFilter
    });
    updateUrl();
  }

  // Clear search
  async function clearSearch() {
    searchQuery = '';
    filters = {
      startDate: '',
      endDate: '',
      event_ids: [],
      member_ids: []
    };
    hasNotesFilter = undefined;
    await attendanceActions.searchAttendanceRecords({});
    updateUrl();
  }

  // Apply filters
  async function applyFilters() {
    await handleSearch();
    showFilters = false;
  }

  // Handle page change
  async function handlePageChange(event: CustomEvent<{ page: number }>) {
    await attendanceActions.changePage(event.detail.page);
    updateUrl();
  }

  // Handle sorting
  async function handleSort(event: CustomEvent<{ column: string; direction: 'asc' | 'desc' }>) {
    await attendanceActions.changeSorting(event.detail.column as any, event.detail.direction);
    updateUrl();
  }

  // Update URL with current state
  function updateUrl() {
    const params = new URLSearchParams();
    if (searchQuery) params.set('q', searchQuery);
    if ($attendancePagination.currentPage > 1) params.set('page', String($attendancePagination.currentPage));
    if (filters.startDate) params.set('startDate', filters.startDate);
    if (filters.endDate) params.set('endDate', filters.endDate);
    
    const newUrl = params.toString() ? `${window.location.pathname}?${params.toString()}` : window.location.pathname;
    history.replaceState({}, '', newUrl);
  }

  // Delete record
  async function deleteRecord(record: AttendanceRecord) {
    recordToDelete = record;
    showDeleteConfirm = true;
  }

  async function confirmDelete() {
    if (!recordToDelete) return;

    try {
      await attendanceActions.deleteAttendanceRecord(recordToDelete.id);
      toastStore.add({
        type: 'success',
        message: 'Attendance record deleted successfully'
      });
      showDeleteConfirm = false;
      recordToDelete = null;
    } catch (error: any) {
      toastStore.add({
        type: 'error',
        message: error.message || 'Failed to delete attendance record'
      });
    }
  }

  // Bulk actions
  async function handleBulkDelete() {
    if ($selectedAttendanceRecords.size === 0) return;

    try {
      await attendanceActions.deleteBulkAttendanceRecords([...$selectedAttendanceRecords]);
      toastStore.add({
        type: 'success',
        message: `Deleted ${$selectedAttendanceRecords.size} attendance records`
      });
      showBulkActions = false;
    } catch (error: any) {
      toastStore.add({
        type: 'error',
        message: error.message || 'Failed to delete attendance records'
      });
    }
  }

  // Export data
  async function handleExport() {
    try {
      const exportFilters = { ...filters, hasNotes: hasNotesFilter };
      await attendanceActions.exportAttendance(exportFormat, exportFilters);
      toastStore.add({
        type: 'success',
        message: 'Attendance data exported successfully'
      });
      showExportModal = false;
    } catch (error: any) {
      toastStore.add({
        type: 'error',
        message: error.message || 'Failed to export attendance data'
      });
    }
  }

  // Format date for display
  function formatDate(dateString: string): string {
    return new Date(dateString).toLocaleDateString();
  }

  // Format time for display
  function formatDateTime(dateString: string): string {
    return new Date(dateString).toLocaleString();
  }
</script>

<div class="container mx-auto p-6">
  <div class="flex flex-col lg:flex-row lg:items-center lg:justify-between mb-6">
    <div>
      <h1 class="text-3xl font-bold text-gray-900">Attendance Records</h1>
      <p class="mt-2 text-gray-600">
        Track and manage member attendance for events
      </p>
    </div>

    <div class="mt-4 lg:mt-0 flex flex-wrap gap-3">
      {#if canExportData}
        <Button
          variant="outline"
          on:click={() => showExportModal = true}
        >
          Export Data
        </Button>
      {/if}

      {#if canManageAttendance}
        <Button
          href="/attendance/record"
          class="bg-blue-600 hover:bg-blue-700"
        >
          Record Attendance
        </Button>
      {/if}
    </div>
  </div>

  {#if $attendanceError}
    <Toast type="error" message={$attendanceError} show={true} />
  {/if}

  <!-- Search and Filters -->
  <div class="bg-white rounded-lg shadow-sm border border-gray-200 p-6 mb-6">
    <div class="flex flex-col lg:flex-row lg:items-center gap-4">
      <div class="flex-1">
        <Input
          type="text"
          placeholder="Search by member name, event title, or notes..."
          bind:value={searchQuery}
          on:keydown={(e) => e.key === 'Enter' && handleSearch()}
        />
      </div>

      <div class="flex gap-2">
        <Button variant="outline" on:click={() => showFilters = !showFilters}>
          Filters
        </Button>
        <Button on:click={handleSearch}>Search</Button>
        {#if searchQuery || filters.startDate || filters.endDate}
          <Button variant="outline" on:click={clearSearch}>Clear</Button>
        {/if}
      </div>
    </div>

    {#if showFilters}
      <div class="mt-6 pt-6 border-t border-gray-200">
        <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4">
          <div>
            <label for="startDate" class="block text-sm font-medium text-gray-700 mb-1">
              Start Date
            </label>
            <Input
              type="date"
              id="startDate"
              bind:value={filters.startDate}
            />
          </div>

          <div>
            <label for="endDate" class="block text-sm font-medium text-gray-700 mb-1">
              End Date
            </label>
            <Input
              type="date"
              id="endDate"
              bind:value={filters.endDate}
            />
          </div>

          <div>
            <label for="hasNotes" class="block text-sm font-medium text-gray-700 mb-1">
              Has Notes
            </label>
            <select
              id="hasNotes"
              bind:value={hasNotesFilter}
              class="w-full rounded-md border border-gray-300 px-3 py-2 text-sm focus:border-blue-500 focus:outline-none focus:ring-1 focus:ring-blue-500"
            >
              <option value={undefined}>All Records</option>
              <option value={true}>With Notes</option>
              <option value={false}>Without Notes</option>
            </select>
          </div>

          <div class="flex items-end">
            <Button on:click={applyFilters} class="w-full">
              Apply Filters
            </Button>
          </div>
        </div>
      </div>
    {/if}
  </div>

  <!-- Bulk Actions -->
  {#if $hasSelectedRecords && canManageAttendance}
    <div class="bg-blue-50 border border-blue-200 rounded-lg p-4 mb-6">
      <div class="flex items-center justify-between">
        <span class="text-sm font-medium text-blue-900">
          {$selectedAttendanceRecords.size} record(s) selected
        </span>
        <div class="flex gap-2">
          <Button
            variant="outline"
            size="sm"
            on:click={() => attendanceActions.deselectAllRecords()}
          >
            Clear Selection
          </Button>
          <Button
            variant="destructive"
            size="sm"
            on:click={() => showBulkActions = true}
          >
            Delete Selected
          </Button>
        </div>
      </div>
    </div>
  {/if}

  <!-- Data Table -->
  {#if $isLoadingAttendance}
    <div class="flex justify-center py-12">
      <Loading />
    </div>
  {:else}
    <DataTable
      data={$attendanceRecords}
      {columns}
      pagination={$attendancePagination}
      selectable={canManageAttendance}
      selectedItems={$selectedAttendanceRecords}
      on:select={(e) => attendanceActions.toggleRecordSelection(e.detail)}
      on:selectAll={() => attendanceActions.selectAllRecords()}
      on:deselectAll={() => attendanceActions.deselectAllRecords()}
      on:pageChange={handlePageChange}
      on:sort={handleSort}
    >
      <svelte:fragment slot="cell" let:item let:column>
        {#if column.key === 'attendance_date'}
          <span class="font-medium">
            {formatDate(item.attendance_date)}
          </span>
        {:else if column.key === 'member.name'}
          <div class="flex flex-col">
            <span class="font-medium text-gray-900">
              {item.member?.name || 'Unknown Member'}
            </span>
            {#if item.member?.email}
              <span class="text-sm text-gray-500">
                {item.member.email}
              </span>
            {/if}
          </div>
        {:else if column.key === 'event.title'}
          <div class="flex flex-col">
            <span class="font-medium text-gray-900">
              {item.event?.title || 'Unknown Event'}
            </span>
            {#if item.event?.start_date}
              <span class="text-sm text-gray-500">
                {formatDateTime(item.event.start_date)}
              </span>
            {/if}
          </div>
        {:else if column.key === 'event.location'}
          <span class="text-gray-600">
            {item.event?.location || '-'}
          </span>
        {:else if column.key === 'notes'}
          <span class="text-gray-600">
            {item.notes || '-'}
          </span>
        {:else if column.key === 'actions'}
          <div class="flex gap-2">
            <Button
              variant="outline"
              size="sm"
              href="/attendance/{item.id}"
            >
              View
            </Button>
            {#if canManageAttendance}
              <Button
                variant="outline"
                size="sm"
                href="/attendance/{item.id}/edit"
              >
                Edit
              </Button>
              <Button
                variant="destructive"
                size="sm"
                on:click={() => deleteRecord(item)}
              >
                Delete
              </Button>
            {/if}
          </div>
        {/if}
      </svelte:fragment>

      <svelte:fragment slot="empty">
        <div class="text-center py-12">
          <svg class="w-12 h-12 text-gray-400 mx-auto mb-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5H7a2 2 0 00-2 2v10a2 2 0 002 2h8a2 2 0 002-2V7a2 2 0 00-2-2h-2M9 5a2 2 0 002 2h2a2 2 0 002-2M9 5a2 2 0 012-2h2a2 2 0 012 2m-3 7h3m-3 4h3m-6-4h.01M9 16h.01"></path>
          </svg>
          <h3 class="text-lg font-medium text-gray-900 mb-2">No attendance records found</h3>
          <p class="text-gray-500 mb-4">
            {#if searchQuery || filters.startDate || filters.endDate}
              Try adjusting your search criteria or filters.
            {:else}
              Start by recording attendance for events.
            {/if}
          </p>
          {#if canManageAttendance}
            <Button href="/attendance/record">
              Record Attendance
            </Button>
          {/if}
        </div>
      </svelte:fragment>
    </DataTable>
  {/if}
</div>

<!-- Delete Confirmation Modal -->
<Modal bind:show={showDeleteConfirm} title="Delete Attendance Record">
  <p class="text-gray-600 mb-6">
    Are you sure you want to delete this attendance record? This action cannot be undone.
  </p>
  
  {#if recordToDelete}
    <div class="bg-gray-50 rounded-lg p-4 mb-6">
      <div class="grid grid-cols-2 gap-4 text-sm">
        <div>
          <span class="font-medium text-gray-700">Member:</span>
          <span class="text-gray-900">{recordToDelete.member?.name}</span>
        </div>
        <div>
          <span class="font-medium text-gray-700">Event:</span>
          <span class="text-gray-900">{recordToDelete.event?.title}</span>
        </div>
        <div>
          <span class="font-medium text-gray-700">Date:</span>
          <span class="text-gray-900">{formatDate(recordToDelete.attendance_date)}</span>
        </div>
      </div>
    </div>
  {/if}

  <div class="flex justify-end gap-3">
    <Button variant="outline" on:click={() => showDeleteConfirm = false}>
      Cancel
    </Button>
    <Button variant="destructive" on:click={confirmDelete}>
      Delete Record
    </Button>
  </div>
</Modal>

<!-- Bulk Delete Confirmation Modal -->
<Modal bind:show={showBulkActions} title="Delete Selected Records">
  <p class="text-gray-600 mb-6">
    Are you sure you want to delete {$selectedAttendanceRecords.size} attendance records? This action cannot be undone.
  </p>

  <div class="flex justify-end gap-3">
    <Button variant="outline" on:click={() => showBulkActions = false}>
      Cancel
    </Button>
    <Button variant="destructive" on:click={handleBulkDelete}>
      Delete {$selectedAttendanceRecords.size} Records
    </Button>
  </div>
</Modal>

<!-- Export Modal -->
<Modal bind:show={showExportModal} title="Export Attendance Data">
  <div class="space-y-4">
    <div>
      <label for="exportFormat" class="block text-sm font-medium text-gray-700 mb-2">
        Export Format
      </label>
      <select
        id="exportFormat"
        bind:value={exportFormat}
        class="w-full rounded-md border border-gray-300 px-3 py-2 text-sm focus:border-blue-500 focus:outline-none focus:ring-1 focus:ring-blue-500"
      >
        <option value="csv">CSV</option>
        <option value="xlsx">Excel</option>
      </select>
    </div>

    <p class="text-sm text-gray-600">
      The export will include all attendance records matching your current filters.
    </p>
  </div>

  <div class="flex justify-end gap-3 mt-6">
    <Button variant="outline" on:click={() => showExportModal = false}>
      Cancel
    </Button>
    <Button on:click={handleExport}>
      Export Data
    </Button>
  </div>
</Modal>

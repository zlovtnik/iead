&lt;script lang="ts"&gt;
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
  import { uiStore } from '$lib/stores/ui.js';
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
  async function handlePageChange(event: CustomEvent&lt;{ page: number }&gt;) {
    await attendanceActions.changePage(event.detail.page);
    updateUrl();
  }

  // Handle sorting
  async function handleSort(event: CustomEvent&lt;{ column: string; direction: 'asc' | 'desc' }&gt;) {
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
      uiStore.addToast({
        type: 'success',
        message: 'Attendance record deleted successfully'
      });
      showDeleteConfirm = false;
      recordToDelete = null;
    } catch (error: any) {
      uiStore.addToast({
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
      uiStore.addToast({
        type: 'success',
        message: `Deleted ${$selectedAttendanceRecords.size} attendance records`
      });
      showBulkActions = false;
    } catch (error: any) {
      uiStore.addToast({
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
      uiStore.addToast({
        type: 'success',
        message: 'Attendance data exported successfully'
      });
      showExportModal = false;
    } catch (error: any) {
      uiStore.addToast({
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
&lt;/script&gt;

&lt;div class="container mx-auto p-6"&gt;
  &lt;div class="flex flex-col lg:flex-row lg:items-center lg:justify-between mb-6"&gt;
    &lt;div&gt;
      &lt;h1 class="text-3xl font-bold text-gray-900"&gt;Attendance Records&lt;/h1&gt;
      &lt;p class="mt-2 text-gray-600"&gt;
        Track and manage member attendance for events
      &lt;/p&gt;
    &lt;/div&gt;

    &lt;div class="mt-4 lg:mt-0 flex flex-wrap gap-3"&gt;
      {#if canExportData}
        &lt;Button
          variant="outline"
          on:click={() =&gt; showExportModal = true}
        &gt;
          Export Data
        &lt;/Button&gt;
      {/if}

      {#if canManageAttendance}
        &lt;Button
          href="/attendance/record"
          class="bg-blue-600 hover:bg-blue-700"
        &gt;
          Record Attendance
        &lt;/Button&gt;
      {/if}
    &lt;/div&gt;
  &lt;/div&gt;

  {#if $attendanceError}
    &lt;Toast type="error" message={$attendanceError} show={true} /&gt;
  {/if}

  &lt;!-- Search and Filters --&gt;
  &lt;div class="bg-white rounded-lg shadow-sm border border-gray-200 p-6 mb-6"&gt;
    &lt;div class="flex flex-col lg:flex-row lg:items-center gap-4"&gt;
      &lt;div class="flex-1"&gt;
        &lt;Input
          type="text"
          placeholder="Search by member name, event title, or notes..."
          bind:value={searchQuery}
          on:keydown={(e) =&gt; e.key === 'Enter' && handleSearch()}
        /&gt;
      &lt;/div&gt;

      &lt;div class="flex gap-2"&gt;
        &lt;Button variant="outline" on:click={() =&gt; showFilters = !showFilters}&gt;
          Filters
        &lt;/Button&gt;
        &lt;Button on:click={handleSearch}&gt;Search&lt;/Button&gt;
        {#if searchQuery || filters.startDate || filters.endDate}
          &lt;Button variant="outline" on:click={clearSearch}&gt;Clear&lt;/Button&gt;
        {/if}
      &lt;/div&gt;
    &lt;/div&gt;

    {#if showFilters}
      &lt;div class="mt-6 pt-6 border-t border-gray-200"&gt;
        &lt;div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4"&gt;
          &lt;div&gt;
            &lt;label for="startDate" class="block text-sm font-medium text-gray-700 mb-1"&gt;
              Start Date
            &lt;/label&gt;
            &lt;Input
              type="date"
              id="startDate"
              bind:value={filters.startDate}
            /&gt;
          &lt;/div&gt;

          &lt;div&gt;
            &lt;label for="endDate" class="block text-sm font-medium text-gray-700 mb-1"&gt;
              End Date
            &lt;/label&gt;
            &lt;Input
              type="date"
              id="endDate"
              bind:value={filters.endDate}
            /&gt;
          &lt;/div&gt;

          &lt;div&gt;
            &lt;label for="hasNotes" class="block text-sm font-medium text-gray-700 mb-1"&gt;
              Has Notes
            &lt;/label&gt;
            &lt;select
              id="hasNotes"
              bind:value={hasNotesFilter}
              class="w-full rounded-md border border-gray-300 px-3 py-2 text-sm focus:border-blue-500 focus:outline-none focus:ring-1 focus:ring-blue-500"
            &gt;
              &lt;option value={undefined}&gt;All Records&lt;/option&gt;
              &lt;option value={true}&gt;With Notes&lt;/option&gt;
              &lt;option value={false}&gt;Without Notes&lt;/option&gt;
            &lt;/select&gt;
          &lt;/div&gt;

          &lt;div class="flex items-end"&gt;
            &lt;Button on:click={applyFilters} class="w-full"&gt;
              Apply Filters
            &lt;/Button&gt;
          &lt;/div&gt;
        &lt;/div&gt;
      &lt;/div&gt;
    {/if}
  &lt;/div&gt;

  &lt;!-- Bulk Actions --&gt;
  {#if $hasSelectedRecords && canManageAttendance}
    &lt;div class="bg-blue-50 border border-blue-200 rounded-lg p-4 mb-6"&gt;
      &lt;div class="flex items-center justify-between"&gt;
        &lt;span class="text-sm font-medium text-blue-900"&gt;
          {$selectedAttendanceRecords.size} record(s) selected
        &lt;/span&gt;
        &lt;div class="flex gap-2"&gt;
          &lt;Button
            variant="outline"
            size="sm"
            on:click={() =&gt; attendanceActions.deselectAllRecords()}
          &gt;
            Clear Selection
          &lt;/Button&gt;
          &lt;Button
            variant="destructive"
            size="sm"
            on:click={() =&gt; showBulkActions = true}
          &gt;
            Delete Selected
          &lt;/Button&gt;
        &lt;/div&gt;
      &lt;/div&gt;
    &lt;/div&gt;
  {/if}

  &lt;!-- Data Table --&gt;
  {#if $isLoadingAttendance}
    &lt;div class="flex justify-center py-12"&gt;
      &lt;Loading /&gt;
    &lt;/div&gt;
  {:else}
    &lt;DataTable
      data={$attendanceRecords}
      {columns}
      pagination={$attendancePagination}
      selectable={canManageAttendance}
      selectedItems={$selectedAttendanceRecords}
      on:select={(e) =&gt; attendanceActions.toggleRecordSelection(e.detail)}
      on:selectAll={() =&gt; attendanceActions.selectAllRecords()}
      on:deselectAll={() =&gt; attendanceActions.deselectAllRecords()}
      on:pageChange={handlePageChange}
      on:sort={handleSort}
    &gt;
      &lt;svelte:fragment slot="cell" let:item let:column&gt;
        {#if column.key === 'attendance_date'}
          &lt;span class="font-medium"&gt;
            {formatDate(item.attendance_date)}
          &lt;/span&gt;
        {:else if column.key === 'member.name'}
          &lt;div class="flex flex-col"&gt;
            &lt;span class="font-medium text-gray-900"&gt;
              {item.member?.name || 'Unknown Member'}
            &lt;/span&gt;
            {#if item.member?.email}
              &lt;span class="text-sm text-gray-500"&gt;
                {item.member.email}
              &lt;/span&gt;
            {/if}
          &lt;/div&gt;
        {:else if column.key === 'event.title'}
          &lt;div class="flex flex-col"&gt;
            &lt;span class="font-medium text-gray-900"&gt;
              {item.event?.title || 'Unknown Event'}
            &lt;/span&gt;
            {#if item.event?.start_date}
              &lt;span class="text-sm text-gray-500"&gt;
                {formatDateTime(item.event.start_date)}
              &lt;/span&gt;
            {/if}
          &lt;/div&gt;
        {:else if column.key === 'event.location'}
          &lt;span class="text-gray-600"&gt;
            {item.event?.location || '-'}
          &lt;/span&gt;
        {:else if column.key === 'notes'}
          &lt;span class="text-gray-600"&gt;
            {item.notes || '-'}
          &lt;/span&gt;
        {:else if column.key === 'actions'}
          &lt;div class="flex gap-2"&gt;
            &lt;Button
              variant="outline"
              size="sm"
              href="/attendance/{item.id}"
            &gt;
              View
            &lt;/Button&gt;
            {#if canManageAttendance}
              &lt;Button
                variant="outline"
                size="sm"
                href="/attendance/{item.id}/edit"
              &gt;
                Edit
              &lt;/Button&gt;
              &lt;Button
                variant="destructive"
                size="sm"
                on:click={() =&gt; deleteRecord(item)}
              &gt;
                Delete
              &lt;/Button&gt;
            {/if}
          &lt;/div&gt;
        {/if}
      &lt;/svelte:fragment&gt;

      &lt;svelte:fragment slot="empty"&gt;
        &lt;div class="text-center py-12"&gt;
          &lt;svg class="w-12 h-12 text-gray-400 mx-auto mb-4" fill="none" stroke="currentColor" viewBox="0 0 24 24"&gt;
            &lt;path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5H7a2 2 0 00-2 2v10a2 2 0 002 2h8a2 2 0 002-2V7a2 2 0 00-2-2h-2M9 5a2 2 0 002 2h2a2 2 0 002-2M9 5a2 2 0 012-2h2a2 2 0 012 2m-3 7h3m-3 4h3m-6-4h.01M9 16h.01"&gt;&lt;/path&gt;
          &lt;/svg&gt;
          &lt;h3 class="text-lg font-medium text-gray-900 mb-2"&gt;No attendance records found&lt;/h3&gt;
          &lt;p class="text-gray-500 mb-4"&gt;
            {#if searchQuery || filters.startDate || filters.endDate}
              Try adjusting your search criteria or filters.
            {:else}
              Start by recording attendance for events.
            {/if}
          &lt;/p&gt;
          {#if canManageAttendance}
            &lt;Button href="/attendance/record"&gt;
              Record Attendance
            &lt;/Button&gt;
          {/if}
        &lt;/div&gt;
      &lt;/svelte:fragment&gt;
    &lt;/DataTable&gt;
  {/if}
&lt;/div&gt;

&lt;!-- Delete Confirmation Modal --&gt;
&lt;Modal bind:show={showDeleteConfirm} title="Delete Attendance Record"&gt;
  &lt;p class="text-gray-600 mb-6"&gt;
    Are you sure you want to delete this attendance record? This action cannot be undone.
  &lt;/p&gt;
  
  {#if recordToDelete}
    &lt;div class="bg-gray-50 rounded-lg p-4 mb-6"&gt;
      &lt;div class="grid grid-cols-2 gap-4 text-sm"&gt;
        &lt;div&gt;
          &lt;span class="font-medium text-gray-700"&gt;Member:&lt;/span&gt;
          &lt;span class="text-gray-900"&gt;{recordToDelete.member?.name}&lt;/span&gt;
        &lt;/div&gt;
        &lt;div&gt;
          &lt;span class="font-medium text-gray-700"&gt;Event:&lt;/span&gt;
          &lt;span class="text-gray-900"&gt;{recordToDelete.event?.title}&lt;/span&gt;
        &lt;/div&gt;
        &lt;div&gt;
          &lt;span class="font-medium text-gray-700"&gt;Date:&lt;/span&gt;
          &lt;span class="text-gray-900"&gt;{formatDate(recordToDelete.attendance_date)}&lt;/span&gt;
        &lt;/div&gt;
      &lt;/div&gt;
    &lt;/div&gt;
  {/if}

  &lt;div class="flex justify-end gap-3"&gt;
    &lt;Button variant="outline" on:click={() =&gt; showDeleteConfirm = false}&gt;
      Cancel
    &lt;/Button&gt;
    &lt;Button variant="destructive" on:click={confirmDelete}&gt;
      Delete Record
    &lt;/Button&gt;
  &lt;/div&gt;
&lt;/Modal&gt;

&lt;!-- Bulk Delete Confirmation Modal --&gt;
&lt;Modal bind:show={showBulkActions} title="Delete Selected Records"&gt;
  &lt;p class="text-gray-600 mb-6"&gt;
    Are you sure you want to delete {$selectedAttendanceRecords.size} attendance records? This action cannot be undone.
  &lt;/p&gt;

  &lt;div class="flex justify-end gap-3"&gt;
    &lt;Button variant="outline" on:click={() =&gt; showBulkActions = false}&gt;
      Cancel
    &lt;/Button&gt;
    &lt;Button variant="destructive" on:click={handleBulkDelete}&gt;
      Delete {$selectedAttendanceRecords.size} Records
    &lt;/Button&gt;
  &lt;/div&gt;
&lt;/Modal&gt;

&lt;!-- Export Modal --&gt;
&lt;Modal bind:show={showExportModal} title="Export Attendance Data"&gt;
  &lt;div class="space-y-4"&gt;
    &lt;div&gt;
      &lt;label for="exportFormat" class="block text-sm font-medium text-gray-700 mb-2"&gt;
        Export Format
      &lt;/label&gt;
      &lt;select
        id="exportFormat"
        bind:value={exportFormat}
        class="w-full rounded-md border border-gray-300 px-3 py-2 text-sm focus:border-blue-500 focus:outline-none focus:ring-1 focus:ring-blue-500"
      &gt;
        &lt;option value="csv"&gt;CSV&lt;/option&gt;
        &lt;option value="xlsx"&gt;Excel&lt;/option&gt;
      &lt;/select&gt;
    &lt;/div&gt;

    &lt;p class="text-sm text-gray-600"&gt;
      The export will include all attendance records matching your current filters.
    &lt;/p&gt;
  &lt;/div&gt;

  &lt;div class="flex justify-end gap-3 mt-6"&gt;
    &lt;Button variant="outline" on:click={() =&gt; showExportModal = false}&gt;
      Cancel
    &lt;/Button&gt;
    &lt;Button on:click={handleExport}&gt;
      Export Data
    &lt;/Button&gt;
  &lt;/div&gt;
&lt;/Modal&gt;

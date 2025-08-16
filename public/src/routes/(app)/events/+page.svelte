<script lang="ts">
  import { onMount } from 'svelte';
  import { goto } from '$app/navigation';
  import { page } from '$app/stores';
  import { events } from '$lib/stores/events.js';
  import { type Event } from '$lib/api/events.js';
  import authStore from '$lib/stores/auth.js';
  import { hasPermission } from '$lib/utils/permissions.js';
  import DataTable from '$lib/components/ui/DataTable.svelte';
  import Button from '$lib/components/ui/Button.svelte';
  import Input from '$lib/components/ui/Input.svelte';
  import Modal from '$lib/components/ui/Modal.svelte';
  import type { TableConfig } from '$lib/types/table.js';

  let searchQuery = $state('');
  let showDeleteModal = $state(false);
  let eventToDelete: Event | null = $state(null);
  let isDeleting = $state(false);
  let viewMode = $state<'list' | 'calendar'>('list');

  // Subscribe to stores
  let eventsData = $state<Event[]>([]);
  let isLoading = $state(false);
  let error = $state<string | null>(null);
  let pagination = $state({ page: 1, limit: 20, total: 0, totalPages: 0, pageSize: 20 });
  let user = $state<any>(null);

  // Subscribe to store updates
  events.subscribe((state) => {
    eventsData = state.events;
    isLoading = state.isLoading;
    error = state.error;
    pagination = { ...state.pagination, pageSize: state.pagination.limit };
  });

  authStore.subscribe((state: any) => {
    user = state.user;
  });

  // Table configuration
  const tableConfig: TableConfig = {
    columns: [
      {
        key: 'title',
        label: 'Event Title',
        sortable: true,
        render: (value: string) => value || 'N/A'
      },
      {
        key: 'start_date',
        label: 'Start Date',
        sortable: true,
        render: (value: string) => {
          const date = new Date(value);
          return date.toLocaleDateString() + ' ' + date.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' });
        }
      },
      {
        key: 'end_date',
        label: 'End Date',
        render: (value: string) => {
          if (!value) return 'N/A';
          const date = new Date(value);
          return date.toLocaleDateString() + ' ' + date.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' });
        }
      },
      {
        key: 'location',
        label: 'Location',
        render: (value: string) => value || 'N/A'
      },
      {
        key: 'attendeeCount',
        label: 'Attendees',
        align: 'center',
        render: (value: number) => value?.toString() || '0'
      },
      {
        key: 'volunteerCount',
        label: 'Volunteers',
        align: 'center',
        render: (value: number) => value?.toString() || '0'
      }
    ],
    actions: [
      {
        label: 'View',
        variant: 'primary',
        onClick: (event: Event) => goto(`/events/${event.id}`),
        permission: 'event:read'
      },
      {
        label: 'Edit',
        onClick: (event: Event) => goto(`/events/${event.id}/edit`),
        permission: 'event:write',
        visible: (event: Event) => hasPermission(user, 'event:write')
      },
      {
        label: 'Attendance',
        onClick: (event: Event) => goto(`/events/${event.id}/attendance`),
        permission: 'attendance:read',
        visible: (event: Event) => hasPermission(user, 'attendance:read')
      },
      {
        label: 'Delete',
        variant: 'danger',
        onClick: (event: Event) => {
          eventToDelete = event;
          showDeleteModal = true;
        },
        permission: 'event:delete',
        visible: (event: Event) => hasPermission(user, 'event:delete')
      }
    ],
    selectable: false,
    hover: true,
    striped: true
  };

  // Search functionality
  let searchTimeout: number;
  function handleSearch() {
    clearTimeout(searchTimeout);
    searchTimeout = setTimeout(() => {
      events.setSearchQuery(searchQuery);
    }, 300);
  }

  // Pagination handlers
  function handlePageChange(newPage: number) {
    events.setPage(newPage);
  }

  function handlePageSizeChange(newSize: number) {
    events.setPageSize(newSize);
  }

  // Sorting handler
  function handleSort(sort: { column: string; direction: 'asc' | 'desc' | null }) {
    if (sort.direction && (sort.column === 'title' || sort.column === 'start_date' || sort.column === 'created_at')) {
      events.setSorting(sort.column as any, sort.direction);
    }
  }

  // View mode handlers
  function setViewMode(mode: 'list' | 'calendar') {
    viewMode = mode;
    if (mode === 'calendar') {
      goto('/events/calendar');
    }
  }

  // Filter handlers
  function filterUpcoming() {
    const today = new Date().toISOString().split('T')[0];
    events.setFilters({ startAfter: today });
  }

  function filterPast() {
    const today = new Date().toISOString().split('T')[0];
    events.setFilters({ startBefore: today });
  }

  function clearAllFilters() {
    searchQuery = '';
    events.clearFilters();
  }

  // Delete event
  async function confirmDelete() {
    if (!eventToDelete) return;
    
    isDeleting = true;
    try {
      await events.deleteEvent(eventToDelete.id);
      showDeleteModal = false;
      eventToDelete = null;
    } catch (err) {
      console.error('Failed to delete event:', err);
    } finally {
      isDeleting = false;
    }
  }

  function cancelDelete() {
    showDeleteModal = false;
    eventToDelete = null;
  }

  // Load events on mount
  onMount(() => {
    events.loadEvents();
  });

  // Check permissions
  const canCreateEvent = $derived(hasPermission(user, 'event:write'));
  const canExportEvents = $derived(hasPermission(user, 'event:read'));
  const canViewCalendar = $derived(hasPermission(user, 'event:read'));
</script>

<svelte:head>
  <title>Events - Church Management</title>
</svelte:head>

<div class="space-y-6">
  <!-- Header -->
  <div class="flex justify-between items-center">
    <div>
      <h1 class="text-2xl font-bold text-gray-900">Events</h1>
      <p class="text-gray-600">Manage church events and activities</p>
    </div>
    
    <div class="flex space-x-3">
      {#if canViewCalendar}
        <Button
          variant="outline"
          onclick={() => goto('/events/calendar')}
        >
          Calendar View
        </Button>
      {/if}
      
      {#if canExportEvents}
        <Button
          variant="outline"
          onclick={() => events.exportEvents('csv')}
        >
          Export CSV
        </Button>
      {/if}
      
      {#if canCreateEvent}
        <Button
          variant="primary"
          onclick={() => goto('/events/create')}
        >
          Create Event
        </Button>
      {/if}
    </div>
  </div>

  <!-- Search and Filters -->
  <div class="bg-white p-4 rounded-lg shadow">
    <div class="flex flex-col sm:flex-row gap-4">
      <div class="flex-1">
        <Input
          type="search"
          placeholder="Search events by title or description..."
          value={searchQuery}
          oninput={(e) => {
            searchQuery = (e.target as HTMLInputElement).value;
            handleSearch();
          }}
          fullWidth
        />
      </div>
      
      <div class="flex space-x-2">
        <Button
          variant="outline"
          onclick={filterUpcoming}
        >
          Upcoming
        </Button>
        <Button
          variant="outline"
          onclick={filterPast}
        >
          Past Events
        </Button>
        <Button
          variant="outline"
          onclick={clearAllFilters}
        >
          Clear Filters
        </Button>
      </div>
    </div>
  </div>

  <!-- Error Display -->
  {#if error}
    <div class="bg-red-50 border border-red-200 rounded-lg p-4">
      <div class="flex">
        <div class="flex-shrink-0">
          <svg class="h-5 w-5 text-red-400" viewBox="0 0 20 20" fill="currentColor">
            <path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zM8.707 7.293a1 1 0 00-1.414 1.414L8.586 10l-1.293 1.293a1 1 0 101.414 1.414L10 11.414l1.293 1.293a1 1 0 001.414-1.414L11.414 10l1.293-1.293a1 1 0 00-1.414-1.414L10 8.586 8.707 7.293z" clip-rule="evenodd" />
          </svg>
        </div>
        <div class="ml-3">
          <p class="text-sm text-red-800">{error}</p>
        </div>
        <div class="ml-auto pl-3">
          <button
            type="button"
            class="inline-flex text-red-400 hover:text-red-600"
            onclick={() => events.clearError()}
            aria-label="Close error message"
          >
            <svg class="h-5 w-5" viewBox="0 0 20 20" fill="currentColor">
              <path fill-rule="evenodd" d="M4.293 4.293a1 1 0 011.414 0L10 8.586l4.293-4.293a1 1 0 111.414 1.414L11.414 10l4.293 4.293a1 1 0 01-1.414 1.414L10 11.414l-4.293 4.293a1 1 0 01-1.414-1.414L8.586 10 4.293 5.707a1 1 0 010-1.414z" clip-rule="evenodd" />
            </svg>
          </button>
        </div>
      </div>
    </div>
  {/if}

  <!-- Events Table -->
  <div class="bg-white rounded-lg shadow">
    <DataTable
      data={eventsData}
      config={tableConfig}
      loading={isLoading}
      error={error}
      pagination={pagination}
      user={user}
      emptyMessage="No events found. Create your first event to get started."
      onsort={(event) => handleSort(event)}
      onpaginate={(event) => {
        const { page, pageSize } = event;
        if (page !== undefined) handlePageChange(page);
        if (pageSize !== undefined) handlePageSizeChange(pageSize);
      }}
    />
  </div>
</div>

<!-- Delete Confirmation Modal -->
<Modal
  open={showDeleteModal}
  title="Delete Event"
  size="md"
  closable={!isDeleting}
>
  {#snippet children()}
    <div class="space-y-4">
      <div class="flex items-center space-x-3">
        <div class="flex-shrink-0">
          <svg class="h-8 w-8 text-red-400" fill="none" viewBox="0 0 24 24" stroke="currentColor">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-2.5L13.732 4c-.77-.833-1.964-.833-2.732 0L4.082 16.5c-.77.833.192 2.5 1.732 2.5z" />
          </svg>
        </div>
        <div>
          <h3 class="text-lg font-medium text-gray-900">
            Are you sure you want to delete this event?
          </h3>
          <p class="text-sm text-gray-500 mt-1">
            This action will permanently delete <strong>{eventToDelete?.title}</strong> and all associated records including attendance and volunteer assignments. This action cannot be undone.
          </p>
        </div>
      </div>
    </div>
  {/snippet}
  
  {#snippet footer()}
    <div class="flex justify-end space-x-3">
      <Button
        variant="outline"
        onclick={cancelDelete}
        disabled={isDeleting}
      >
        Cancel
      </Button>
      <Button
        variant="error"
        onclick={confirmDelete}
        loading={isDeleting}
        disabled={isDeleting}
      >
        Delete Event
      </Button>
    </div>
  {/snippet}
</Modal>

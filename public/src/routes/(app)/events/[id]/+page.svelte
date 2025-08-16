<script lang="ts">
  import { onMount } from 'svelte';
  import { page } from '$app/stores';
  import { goto } from '$app/navigation';
  import { events } from '$lib/stores/events.js';
  import { type Event } from '$lib/api/events.js';
  import authStore from '$lib/stores/auth.js';
  import { hasPermission } from '$lib/utils/permissions.js';
  import Button from '$lib/components/ui/Button.svelte';
  import Modal from '$lib/components/ui/Modal.svelte';
  import Loading from '$lib/components/ui/Loading.svelte';

  let eventId = $derived(parseInt($page.params.id || '0'));
  let event: Event | null = $state(null);
  let eventStats = $state<any>(null);
  let isLoading = $state(true);
  let isLoadingStats = $state(false);
  let error = $state<string | null>(null);
  let showDeleteModal = $state(false);
  let isDeleting = $state(false);
  let user = $state(null);

  // Subscribe to auth store
  authStore.subscribe((state: any) => {
    user = state.user;
  });

  // Subscribe to events store
  events.subscribe((state) => {
    if (state.selectedEvent && state.selectedEvent.id === eventId) {
      event = state.selectedEvent;
    }
    error = state.error;
    isLoading = state.isLoading;
    isDeleting = state.isDeleting;
  });

  async function loadEvent() {
    try {
      isLoading = true;
      event = await events.loadEvent(eventId);
      
      // Load event statistics
      if (hasPermission(user, 'event:read')) {
        isLoadingStats = true;
        try {
          eventStats = await events.loadEventStats(eventId);
        } catch (err) {
          console.error('Failed to load event stats:', err);
        } finally {
          isLoadingStats = false;
        }
      }
    } catch (err) {
      console.error('Failed to load event:', err);
      error = 'Failed to load event details';
    } finally {
      isLoading = false;
    }
  }

  async function handleDelete() {
    if (!event) return;
    
    try {
      await events.deleteEvent(event.id);
      await goto('/events');
    } catch (err) {
      console.error('Failed to delete event:', err);
    }
  }

  function confirmDelete() {
    showDeleteModal = true;
  }

  function cancelDelete() {
    showDeleteModal = false;
  }

  function formatDateTime(dateStr: string): string {
    const date = new Date(dateStr);
    return date.toLocaleDateString() + ' at ' + date.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' });
  }

  function formatDate(dateStr: string): string {
    return new Date(dateStr).toLocaleDateString();
  }

  function isUpcoming(dateStr: string): boolean {
    return new Date(dateStr) > new Date();
  }

  onMount(() => {
    loadEvent();
  });

  // Check permissions
  const canEdit = $derived(hasPermission(user, 'event:write'));
  const canDelete = $derived(hasPermission(user, 'event:delete'));
  const canViewStats = $derived(hasPermission(user, 'event:read'));
  const canManageAttendance = $derived(hasPermission(user, 'attendance:write'));
  const canManageVolunteers = $derived(hasPermission(user, 'volunteer:write'));
</script>

<svelte:head>
  <title>{event?.title || 'Event'} - Church Management</title>
</svelte:head>

<div class="space-y-6">
  <!-- Header -->
  <div class="flex justify-between items-start">
    <div>
      <div class="flex items-center space-x-2 text-sm text-gray-500 mb-2">
        <button
          onclick={() => goto('/events')}
          class="hover:text-gray-700 transition-colors"
        >
          Events
        </button>
        <span>›</span>
        <span>{event?.title || 'Loading...'}</span>
      </div>
      
      {#if event}
        <h1 class="text-2xl font-bold text-gray-900">{event.title}</h1>
        <p class="text-gray-600">
          {#if isUpcoming(event.start_date)}
            <span class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-green-100 text-green-800 mr-2">
              Upcoming
            </span>
          {:else}
            <span class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-gray-100 text-gray-800 mr-2">
              Past Event
            </span>
          {/if}
          {formatDateTime(event.start_date)}
        </p>
      {:else}
        <h1 class="text-2xl font-bold text-gray-900">Loading...</h1>
      {/if}
    </div>
    
    <div class="flex space-x-3">
      {#if canEdit && event}
        <Button
          variant="outline"
          onclick={() => goto(`/events/${event.id}/edit`)}
        >
          Edit Event
        </Button>
      {/if}
      
      {#if canDelete && event}
        <Button
          variant="error"
          onclick={confirmDelete}
        >
          Delete Event
        </Button>
      {/if}
    </div>
  </div>

  {#if isLoading}
    <div class="flex justify-center py-12">
      <Loading />
    </div>
  {:else if error}
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
      </div>
    </div>
  {:else if event}
    <div class="grid grid-cols-1 lg:grid-cols-3 gap-6">
      <!-- Event Information -->
      <div class="lg:col-span-2 space-y-6">
        <!-- Basic Information -->
        <div class="bg-white rounded-lg shadow p-6">
          <h2 class="text-lg font-semibold text-gray-900 mb-4">Event Details</h2>
          <dl class="grid grid-cols-1 sm:grid-cols-2 gap-4">
            <div>
              <dt class="text-sm font-medium text-gray-500">Event Title</dt>
              <dd class="mt-1 text-sm text-gray-900">{event.title}</dd>
            </div>
            
            <div>
              <dt class="text-sm font-medium text-gray-500">Start Date & Time</dt>
              <dd class="mt-1 text-sm text-gray-900">{formatDateTime(event.start_date)}</dd>
            </div>
            
            {#if event.end_date}
              <div>
                <dt class="text-sm font-medium text-gray-500">End Date & Time</dt>
                <dd class="mt-1 text-sm text-gray-900">{formatDateTime(event.end_date)}</dd>
              </div>
            {/if}
            
            <div>
              <dt class="text-sm font-medium text-gray-500">Location</dt>
              <dd class="mt-1 text-sm text-gray-900">
                {#if event.location}
                  {event.location}
                {:else}
                  <span class="text-gray-400">Not specified</span>
                {/if}
              </dd>
            </div>
            
            <div>
              <dt class="text-sm font-medium text-gray-500">Created</dt>
              <dd class="mt-1 text-sm text-gray-900">{formatDate(event.created_at)}</dd>
            </div>
          </dl>

          {#if event.description}
            <div class="mt-6">
              <dt class="text-sm font-medium text-gray-500">Description</dt>
              <dd class="mt-2 text-sm text-gray-900 whitespace-pre-wrap">{event.description}</dd>
            </div>
          {/if}
        </div>

        <!-- Event Statistics -->
        {#if canViewStats}
          <div class="bg-white rounded-lg shadow p-6">
            <h2 class="text-lg font-semibold text-gray-900 mb-4">Event Statistics</h2>
            
            {#if eventStats}
              <dl class="grid grid-cols-1 sm:grid-cols-3 gap-4">
                <div>
                  <dt class="text-sm font-medium text-gray-500">Total Attendees</dt>
                  <dd class="mt-1 text-2xl font-semibold text-gray-900">{eventStats.totalAttendees || 0}</dd>
                </div>
                
                <div>
                  <dt class="text-sm font-medium text-gray-500">Volunteers</dt>
                  <dd class="mt-1 text-2xl font-semibold text-gray-900">{eventStats.totalVolunteers || 0}</dd>
                </div>
                
                <div>
                  <dt class="text-sm font-medium text-gray-500">Volunteer Hours</dt>
                  <dd class="mt-1 text-2xl font-semibold text-gray-900">{eventStats.totalVolunteerHours || 0}</dd>
                </div>
              </dl>
            {:else if isLoadingStats}
              <div class="animate-pulse">
                <div class="grid grid-cols-1 sm:grid-cols-3 gap-4">
                  {#each Array(3) as _}
                    <div>
                      <div class="h-4 bg-gray-200 rounded w-3/4 mb-2"></div>
                      <div class="h-8 bg-gray-200 rounded w-1/2"></div>
                    </div>
                  {/each}
                </div>
              </div>
            {:else}
              <p class="text-sm text-gray-500">Unable to load statistics</p>
            {/if}
          </div>
        {/if}
      </div>

      <!-- Sidebar -->
      <div class="space-y-6">
        <!-- Quick Actions -->
        <div class="bg-white rounded-lg shadow p-6">
          <h3 class="text-lg font-semibold text-gray-900 mb-4">Actions</h3>
          <div class="space-y-2">
            {#if canManageAttendance}
              <Button
                variant="outline"
                fullWidth
                onclick={() => goto(`/events/${event.id}/attendance`)}
              >
                Manage Attendance
              </Button>
            {/if}
            
            {#if canManageVolunteers}
              <Button
                variant="outline"
                fullWidth
                onclick={() => goto(`/events/${event.id}/volunteers`)}
              >
                Manage Volunteers
              </Button>
            {/if}
            
            <Button
              variant="outline"
              fullWidth
              onclick={() => goto('/events/calendar')}
            >
              View Calendar
            </Button>
          </div>
        </div>

        <!-- Event Status -->
        <div class="bg-white rounded-lg shadow p-6">
          <h3 class="text-lg font-semibold text-gray-900 mb-4">Event Status</h3>
          <div class="space-y-3">
            <div class="flex items-center justify-between">
              <span class="text-sm text-gray-500">Status</span>
              {#if isUpcoming(event.start_date)}
                <span class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-green-100 text-green-800">
                  Upcoming
                </span>
              {:else}
                <span class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-gray-100 text-gray-800">
                  Completed
                </span>
              {/if}
            </div>
            
            <div class="flex items-center justify-between">
              <span class="text-sm text-gray-500">Duration</span>
              <span class="text-sm text-gray-900">
                {#if event.end_date}
                  {Math.ceil((new Date(event.end_date).getTime() - new Date(event.start_date).getTime()) / (1000 * 60 * 60))} hours
                {:else}
                  Not specified
                {/if}
              </span>
            </div>
          </div>
        </div>
      </div>
    </div>
  {:else}
    <div class="text-center py-12">
      <p class="text-gray-500">Event not found</p>
      <Button
        variant="outline"
        onclick={() => goto('/events')}
        class="mt-4"
      >
        Back to Events
      </Button>
    </div>
  {/if}
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
            This action will permanently delete <strong>{event?.title}</strong> and all associated records including attendance and volunteer assignments. This action cannot be undone.
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
        onclick={handleDelete}
        loading={isDeleting}
        disabled={isDeleting}
      >
        Delete Event
      </Button>
    </div>
  {/snippet}
</Modal>

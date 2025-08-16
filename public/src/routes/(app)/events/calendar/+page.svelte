<script lang="ts">
  import { onMount } from 'svelte';
  import { goto } from '$app/navigation';
  import { events } from '$lib/stores/events.js';
  import { type Event } from '$lib/api/events.js';
  import authStore from '$lib/stores/auth.js';
  import { hasPermission } from '$lib/utils/permissions.js';
  import Button from '$lib/components/ui/Button.svelte';
  import Loading from '$lib/components/ui/Loading.svelte';

  let currentDate = $state(new Date());
  let calendarEvents = $state<Event[]>([]);
  let isLoading = $state(false);
  let error = $state<string | null>(null);
  let user = $state<any>(null);

  authStore.subscribe((state: any) => {
    user = state.user;
  });

  // Calendar view helpers
  function getFirstDayOfMonth(date: Date): Date {
    return new Date(date.getFullYear(), date.getMonth(), 1);
  }

  function getLastDayOfMonth(date: Date): Date {
    return new Date(date.getFullYear(), date.getMonth() + 1, 0);
  }

  function getFirstDayOfCalendar(date: Date): Date {
    const firstDay = getFirstDayOfMonth(date);
    const dayOfWeek = firstDay.getDay();
    return new Date(firstDay.getTime() - dayOfWeek * 24 * 60 * 60 * 1000);
  }

  function getLastDayOfCalendar(date: Date): Date {
    const lastDay = getLastDayOfMonth(date);
    const dayOfWeek = lastDay.getDay();
    const daysToAdd = 6 - dayOfWeek;
    return new Date(lastDay.getTime() + daysToAdd * 24 * 60 * 60 * 1000);
  }

  function generateCalendarDays(date: Date): Date[] {
    const firstDay = getFirstDayOfCalendar(date);
    const lastDay = getLastDayOfCalendar(date);
    const days: Date[] = [];
    
    for (let d = new Date(firstDay); d <= lastDay; d.setDate(d.getDate() + 1)) {
      days.push(new Date(d));
    }
    
    return days;
  }

  function getEventsForDay(date: Date): Event[] {
    const dateStr = date.toISOString().split('T')[0];
    return calendarEvents.filter(event => {
      const eventDate = new Date(event.start_date).toISOString().split('T')[0];
      return eventDate === dateStr;
    });
  }

  function isToday(date: Date): boolean {
    const today = new Date();
    return date.toDateString() === today.toDateString();
  }

  function isSameMonth(date: Date, month: Date): boolean {
    return date.getMonth() === month.getMonth() && date.getFullYear() === month.getFullYear();
  }

  function formatTime(dateStr: string): string {
    return new Date(dateStr).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' });
  }

  // Navigation functions
  function goToPreviousMonth() {
    currentDate = new Date(currentDate.getFullYear(), currentDate.getMonth() - 1, 1);
    loadEventsForMonth();
  }

  function goToNextMonth() {
    currentDate = new Date(currentDate.getFullYear(), currentDate.getMonth() + 1, 1);
    loadEventsForMonth();
  }

  function goToToday() {
    currentDate = new Date();
    loadEventsForMonth();
  }

  // Load events for the current month
  async function loadEventsForMonth() {
    isLoading = true;
    error = null;
    
    try {
      const firstDay = getFirstDayOfCalendar(currentDate);
      const lastDay = getLastDayOfCalendar(currentDate);
      
      calendarEvents = await events.loadEventsForCalendar(
        firstDay.toISOString().split('T')[0],
        lastDay.toISOString().split('T')[0]
      );
    } catch (err) {
      error = 'Failed to load events for calendar view';
      console.error('Calendar load error:', err);
    } finally {
      isLoading = false;
    }
  }

  onMount(() => {
    loadEventsForMonth();
  });

  // Computed values
  const calendarDays = $derived(generateCalendarDays(currentDate));
  const monthYear = $derived(currentDate.toLocaleDateString('en-US', { month: 'long', year: 'numeric' }));
  const canCreateEvent = $derived(hasPermission(user, 'event:write'));
</script>

<svelte:head>
  <title>Event Calendar - Church Management</title>
</svelte:head>

<div class="space-y-6">
  <!-- Header -->
  <div class="flex justify-between items-center">
    <div>
      <h1 class="text-2xl font-bold text-gray-900">Event Calendar</h1>
      <p class="text-gray-600">View events in calendar format</p>
    </div>
    
    <div class="flex space-x-3">
      <Button
        variant="outline"
        onclick={() => goto('/events')}
      >
        List View
      </Button>
      
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

  <!-- Calendar Navigation -->
  <div class="bg-white rounded-lg shadow p-4">
    <div class="flex justify-between items-center">
      <div class="flex items-center space-x-4">
        <h2 class="text-xl font-semibold text-gray-900">{monthYear}</h2>
        <Button
          variant="outline"
          size="sm"
          onclick={goToToday}
        >
          Today
        </Button>
      </div>
      
      <div class="flex space-x-2">
        <Button
          variant="outline"
          size="sm"
          onclick={goToPreviousMonth}
          disabled={isLoading}
        >
          Previous
        </Button>
        <Button
          variant="outline"
          size="sm"
          onclick={goToNextMonth}
          disabled={isLoading}
        >
          Next
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
      </div>
    </div>
  {/if}

  <!-- Calendar Grid -->
  <div class="bg-white rounded-lg shadow overflow-hidden">
    {#if isLoading}
      <div class="flex justify-center py-12">
        <Loading />
      </div>
    {:else}
      <!-- Days of week header -->
      <div class="grid grid-cols-7 bg-gray-50 border-b">
        {#each ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'] as day}
          <div class="p-4 text-center text-sm font-medium text-gray-900 border-r last:border-r-0">
            {day}
          </div>
        {/each}
      </div>
      
      <!-- Calendar days -->
      <div class="grid grid-cols-7">
        {#each calendarDays as day, i}
          <div class="min-h-32 border-r border-b last:border-r-0 {i >= 35 ? 'border-b-0' : ''} {!isSameMonth(day, currentDate) ? 'bg-gray-50' : 'bg-white'}">
            <div class="p-2">
              <!-- Day number -->
              <div class="flex justify-between items-start mb-2">
                <span class="text-sm {isToday(day) ? 'bg-blue-600 text-white rounded-full w-6 h-6 flex items-center justify-center' : isSameMonth(day, currentDate) ? 'text-gray-900' : 'text-gray-400'}">
                  {day.getDate()}
                </span>
              </div>
              
              <!-- Events for this day -->
              <div class="space-y-1">
                {#each getEventsForDay(day) as event}
                  <button
                    class="w-full text-left text-xs p-1 rounded bg-blue-100 text-blue-800 hover:bg-blue-200 transition-colors"
                    onclick={() => goto(`/events/${event.id}`)}
                  >
                    <div class="font-medium truncate">{event.title}</div>
                    <div class="opacity-75">{formatTime(event.start_date)}</div>
                  </button>
                {/each}
              </div>
            </div>
          </div>
        {/each}
      </div>
    {/if}
  </div>

  <!-- Legend -->
  <div class="bg-white rounded-lg shadow p-4">
    <h3 class="text-sm font-medium text-gray-900 mb-2">Calendar Legend</h3>
    <div class="flex flex-wrap gap-4 text-sm">
      <div class="flex items-center space-x-2">
        <div class="w-4 h-4 bg-blue-100 rounded"></div>
        <span class="text-gray-600">Events</span>
      </div>
      <div class="flex items-center space-x-2">
        <div class="w-4 h-4 bg-blue-600 rounded-full"></div>
        <span class="text-gray-600">Today</span>
      </div>
      <div class="flex items-center space-x-2">
        <div class="w-4 h-4 bg-gray-50 border rounded"></div>
        <span class="text-gray-600">Other months</span>
      </div>
    </div>
  </div>
</div>

<script lang="ts">
  import { onMount } from 'svelte';
  import { page } from '$app/stores';
  import { goto } from '$app/navigation';
  import { events } from '$lib/stores/events.js';
  import { type Event, type EventFormData } from '$lib/api/events.js';
  import { eventUpdateSchema } from '$lib/validators/event.js';
  import FormWrapper from '$lib/components/forms/FormWrapper.svelte';
  import FormField from '$lib/components/forms/FormField.svelte';
  import Button from '$lib/components/ui/Button.svelte';
  import Loading from '$lib/components/ui/Loading.svelte';

  let eventId = $derived(parseInt($page.params.id || '0'));
  let event: Event | null = $state(null);
  let isLoading = $state(true);
  let isSubmitting = $state(false);
  let error = $state<string | null>(null);

  // Subscribe to events store
  events.subscribe((state) => {
    if (state.selectedEvent && state.selectedEvent.id === eventId) {
      event = state.selectedEvent;
    }
    error = state.error;
    isLoading = state.isLoading;
    isSubmitting = state.isUpdating;
  });

  async function loadEvent() {
    try {
      isLoading = true;
      event = await events.loadEvent(eventId);
    } catch (err) {
      console.error('Failed to load event:', err);
      error = 'Failed to load event details';
    } finally {
      isLoading = false;
    }
  }

  async function handleSubmit(data: EventFormData) {
    if (!event) return;
    
    try {
      const updatedEvent = await events.updateEvent(event.id, data);
      // Redirect to the event's detail page
      await goto(`/events/${updatedEvent.id}`);
    } catch (error) {
      console.error('Failed to update event:', error);
      // Error is handled by FormWrapper
    }
  }

  function handleCancel() {
    if (event) {
      goto(`/events/${event.id}`);
    } else {
      goto('/events');
    }
  }

  // Format date for datetime-local input
  function formatDateForInput(dateStr: string): string {
    if (!dateStr) return '';
    const date = new Date(dateStr);
    return date.toISOString().slice(0, 16); // YYYY-MM-DDTHH:mm
  }

  // Format date from datetime-local input
  function formatDateFromInput(inputStr: string): string {
    if (!inputStr) return '';
    return new Date(inputStr).toISOString();
  }

  onMount(() => {
    loadEvent();
  });

  // Prepare initial form data
  const initialData = $derived(() => {
    if (!event) return {};
    
    return {
      title: event.title || '',
      description: event.description || '',
      start_date: event.start_date || '',
      end_date: event.end_date || '',
      location: event.location || ''
    };
  });
</script>

<svelte:head>
  <title>Edit {event?.title || 'Event'} - Church Management</title>
</svelte:head>

<div class="max-w-2xl mx-auto space-y-6">
  <!-- Header -->
  <div class="flex items-center justify-between">
    <div>
      <div class="flex items-center space-x-2 text-sm text-gray-500 mb-2">
        <button
          onclick={() => goto('/events')}
          class="hover:text-gray-700 transition-colors"
        >
          Events
        </button>
        <span>›</span>
        {#if event}
          <button
            onclick={() => goto(`/events/${event.id}`)}
            class="hover:text-gray-700 transition-colors"
          >
            {event.title}
          </button>
          <span>›</span>
        {/if}
        <span>Edit</span>
      </div>
      
      <h1 class="text-2xl font-bold text-gray-900">
        Edit {event?.title || 'Event'}
      </h1>
      <p class="text-gray-600">Update event information and details</p>
    </div>
    
    <Button
      variant="outline"
      onclick={handleCancel}
      disabled={isSubmitting}
    >
      Cancel
    </Button>
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
    <!-- Form -->
    <div class="bg-white rounded-lg shadow p-6">
      <FormWrapper
        schema={eventUpdateSchema}
        initialData={initialData}
        onsubmit={handleSubmit}
        submitText="Update Event"
        submitVariant="primary"
        disabled={isSubmitting}
      >
        {#snippet children(form: any)}
          <div class="space-y-6">
            <!-- Basic Information -->
            <div>
              <h3 class="text-lg font-medium text-gray-900 mb-4">Event Details</h3>
              <div class="space-y-4">
                <FormField
                  name="title"
                  label="Event Title"
                  type="text"
                  required
                  placeholder="Enter event title"
                  bind:value={form.formData.title}
                  error={form.errors.title}
                  onchange={(value) => form.handleFieldChange('title', value)}
                  onblur={(e) => form.handleFieldBlur('title', (e.target as HTMLInputElement)?.value || '')}
                  fullWidth
                />
                
                <FormField
                  name="description"
                  label="Description"
                  type="textarea"
                  placeholder="Enter event description (optional)"
                  bind:value={form.formData.description}
                  error={form.errors.description}
                  onchange={(value) => form.handleFieldChange('description', value)}
                  onblur={(e) => form.handleFieldBlur('description', (e.target as HTMLTextAreaElement)?.value || '')}
                  rows={4}
                  fullWidth
                />
                
                <FormField
                  name="location"
                  label="Location"
                  type="text"
                  placeholder="Enter event location (optional)"
                  bind:value={form.formData.location}
                  error={form.errors.location}
                  onchange={(value) => form.handleFieldChange('location', value)}
                  onblur={(e) => form.handleFieldBlur('location', (e.target as HTMLInputElement)?.value || '')}
                  helperText="e.g., Main Sanctuary, Fellowship Hall, or external address"
                  fullWidth
                />
              </div>
            </div>

            <!-- Date and Time -->
            <div>
              <h3 class="text-lg font-medium text-gray-900 mb-4">Date & Time</h3>
              <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
                <FormField
                  name="start_date"
                  label="Start Date & Time"
                  type="datetime-local"
                  required
                  value={formatDateForInput(form.formData.start_date)}
                  error={form.errors.start_date}
                  onchange={(value) => {
                    const isoValue = formatDateFromInput(value);
                    form.handleFieldChange('start_date', isoValue);
                  }}
                  onblur={(e) => {
                    const value = (e.target as HTMLInputElement)?.value || '';
                    const isoValue = formatDateFromInput(value);
                    form.handleFieldBlur('start_date', isoValue);
                  }}
                  helperText="When does the event start?"
                  fullWidth
                />
                
                <FormField
                  name="end_date"
                  label="End Date & Time"
                  type="datetime-local"
                  value={formatDateForInput(form.formData.end_date || '')}
                  error={form.errors.end_date}
                  onchange={(value) => {
                    const isoValue = value ? formatDateFromInput(value) : '';
                    form.handleFieldChange('end_date', isoValue);
                  }}
                  onblur={(e) => {
                    const value = (e.target as HTMLInputElement)?.value || '';
                    const isoValue = value ? formatDateFromInput(value) : '';
                    form.handleFieldBlur('end_date', isoValue);
                  }}
                  helperText="Optional - When does the event end?"
                  fullWidth
                />
              </div>
            </div>

            <!-- Event History -->
            <div>
              <h3 class="text-lg font-medium text-gray-900 mb-4">Event Information</h3>
              <div class="bg-gray-50 rounded-lg p-4">
                <dl class="grid grid-cols-1 sm:grid-cols-2 gap-4">
                  <div>
                    <dt class="text-sm font-medium text-gray-500">Created</dt>
                    <dd class="mt-1 text-sm text-gray-900">
                      {event ? new Date(event.created_at).toLocaleDateString() : 'N/A'}
                    </dd>
                  </div>
                  
                  <div>
                    <dt class="text-sm font-medium text-gray-500">Event ID</dt>
                    <dd class="mt-1 text-sm text-gray-900">#{event ? event.id : 'N/A'}</dd>
                  </div>
                </dl>
              </div>
            </div>

            <!-- Form Actions -->
            <div class="flex justify-end space-x-3 pt-6 border-t border-gray-200">
              <Button
                type="button"
                variant="outline"
                onclick={handleCancel}
                disabled={isSubmitting}
              >
                Cancel
              </Button>
              <Button
                type="submit"
                variant="primary"
                loading={isSubmitting}
                disabled={isSubmitting}
              >
                Update Event
              </Button>
            </div>
          </div>
        {/snippet}
      </FormWrapper>
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

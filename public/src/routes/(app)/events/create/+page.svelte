<script lang="ts">
  import { goto } from '$app/navigation';
  import { events } from '$lib/stores/events.js';
  import { eventCreateSchema } from '$lib/validators/event.js';
  import FormWrapper from '$lib/components/forms/FormWrapper.svelte';
  import FormField from '$lib/components/forms/FormField.svelte';
  import Button from '$lib/components/ui/Button.svelte';
  import type { EventFormData } from '$lib/api/events.js';

  let isSubmitting = $state(false);

  const initialData: Partial<EventFormData> = {
    title: '',
    description: '',
    start_date: '',
    end_date: '',
    location: ''
  };

  async function handleSubmit(data: EventFormData) {
    isSubmitting = true;
    try {
      const newEvent = await events.createEvent(data);
      // Redirect to the new event's detail page
      await goto(`/events/${newEvent.id}`);
    } catch (error) {
      console.error('Failed to create event:', error);
      // Error is handled by FormWrapper
    } finally {
      isSubmitting = false;
    }
  }

  function handleCancel() {
    goto('/events');
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
</script>

<svelte:head>
  <title>Create Event - Church Management</title>
</svelte:head>

<div class="max-w-2xl mx-auto space-y-6">
  <!-- Header -->
  <div class="flex items-center justify-between">
    <div>
      <h1 class="text-2xl font-bold text-gray-900">Create New Event</h1>
      <p class="text-gray-600">Add a new event to the church calendar</p>
    </div>
    
    <Button
      variant="outline"
      onclick={handleCancel}
      disabled={isSubmitting}
    >
      Cancel
    </Button>
  </div>

  <!-- Form -->
  <div class="bg-white rounded-lg shadow p-6">
    <FormWrapper
      schema={eventCreateSchema}
      initialData={initialData}
      onsubmit={handleSubmit}
      submitText="Create Event"
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
                bind:value={form.formData.start_date}
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
                bind:value={form.formData.end_date}
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
              Create Event
            </Button>
          </div>
        </div>
      {/snippet}
    </FormWrapper>
  </div>
</div>
